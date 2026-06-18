#!/bin/sh

KC_BASE="http://keycloak:8080"
REALM="escritorio-adv"
CLIENT_ID="backend-api"
BACKEND_CLIENT_SECRET="gUHc20eRvmYZBKiMUSv0M5qa5A44x7ev"
TEST_USER="admin@escritorio.com"
TEST_PASS="admin123"

# ── 1. Aguardar Keycloak ────────────────────────────────────────────────────
echo "Aguardando Keycloak em $KC_BASE ..."
i=0
while [ "$i" -lt 90 ]; do
  if curl -s -o /dev/null -w "%{http_code}" "$KC_BASE/realms/master" 2>/dev/null | grep -q "200"; then
    echo "Keycloak está pronto!"
    break
  fi
  i=$((i + 1))
  if [ "$i" -eq 90 ]; then
    echo "Keycloak não iniciou a tempo (90 tentativas)"
    exit 1
  fi
  sleep 2
done

# ── 2. Obter admin token ────────────────────────────────────────────────────
echo ""
echo "Obtendo token de admin..."

# Retry para obter token (Keycloak pode demorar um pouco mais para aceitar logins)
ADMIN_TOKEN=""
j=0
while [ "$j" -lt 10 ]; do
  TOKEN_RESP=$(curl -s -X POST "$KC_BASE/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" 2>/dev/null || echo "")

  ADMIN_TOKEN=$(echo "$TOKEN_RESP" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

  if [ -n "$ADMIN_TOKEN" ]; then
    break
  fi
  j=$((j + 1))
  echo "  tentativa $j/10..."
  sleep 3
done

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Falha ao obter token de admin após 10 tentativas"
  echo " Última resposta: $TOKEN_RESP"
  exit 1
fi
echo "Token de admin obtido"

AUTH="Authorization: Bearer $ADMIN_TOKEN"

# ── 3. Criar realm ──────────────────────────────────────────────────────────
echo ""
echo "Verificando realm '$REALM'..."
REALM_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$KC_BASE/admin/realms/$REALM" -H "$AUTH")

if [ "$REALM_CHECK" = "200" ]; then
  echo "Realm '$REALM' já existe, pulando"
else
  echo "Criando realm '$REALM'..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_BASE/admin/realms" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{\"realm\": \"$REALM\", \"enabled\": true}")

  if [ "$STATUS" = "201" ]; then
    echo "Realm '$REALM' criado"
  else
    echo "Resposta inesperada ao criar realm: $STATUS"
  fi
fi

# ── 4. Desabilitar Required Actions ─────────────────────────────────────────
echo ""
echo "🔧 Desabilitando required actions no realm '$REALM'..."

for ACTION in CONFIGURE_TOTP UPDATE_PASSWORD UPDATE_PROFILE VERIFY_EMAIL; do
  # Obter a config atual da action
  ACTION_JSON=$(curl -s "$KC_BASE/admin/realms/$REALM/authentication/required-actions/$ACTION" \
    -H "$AUTH" 2>/dev/null || echo "")

  if [ -n "$ACTION_JSON" ] && echo "$ACTION_JSON" | grep -q "alias"; then
    # Substituir "enabled":true por "enabled":false
    UPDATED_JSON=$(echo "$ACTION_JSON" | sed 's/"enabled"[[:space:]]*:[[:space:]]*true/"enabled":false/g' | sed 's/"defaultAction"[[:space:]]*:[[:space:]]*true/"defaultAction":false/g')

    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
      "$KC_BASE/admin/realms/$REALM/authentication/required-actions/$ACTION" \
      -H "$AUTH" \
      -H "Content-Type: application/json" \
      -d "$UPDATED_JSON")

    if [ "$STATUS" = "204" ]; then
      echo "$ACTION → desabilitado"
    else
      echo "$ACTION → resposta $STATUS"
    fi
  else
    echo " $ACTION → não encontrado ou já configurado"
  fi
done

# ── 5. Criar client ─────────────────────────────────────────────────────────
echo ""
echo "Verificando client '$CLIENT_ID'..."
CLIENT_EXISTING_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/clients?clientId=$CLIENT_ID" \
  -H "$AUTH" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -n "$CLIENT_EXISTING_ID" ]; then
  echo "Client '$CLIENT_ID' já existe, pulando"
else
  echo "Criando client '$CLIENT_ID'..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_BASE/admin/realms/$REALM/clients" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"$CLIENT_ID\",
      \"enabled\": true,
      \"protocol\": \"openid-connect\",
      \"publicClient\": true,
      \"directAccessGrantsEnabled\": true,
      \"standardFlowEnabled\": true,
      \"redirectUris\": [
        \"http://localhost:8000/*\",
        \"http://localhost:3000/*\",
        \"https://escritorio-adv.vercel.app/*\",
        \"https://escritorio-adv-two.vercel.app/*\",
        \"https://escritorio-adv-mauricio-araujoos-projects.vercel.app/*\",
        \"https://escritorio-adv-git-main-mauricio-araujoos-projects.vercel.app/*\"
      ],
      \"webOrigins\": [
        \"http://localhost:3000\",
        \"https://escritorio-adv.vercel.app\",
        \"https://escritorio-adv-two.vercel.app\",
        \"https://escritorio-adv-mauricio-araujoos-projects.vercel.app\",
        \"https://escritorio-adv-git-main-mauricio-araujoos-projects.vercel.app\"
      ]
    }")

  if [ "$STATUS" = "201" ]; then
    echo "Client '$CLIENT_ID' criado (público)"
  else
    echo "Resposta inesperada ao criar client: $STATUS"
  fi
fi

# ── 5b. Criar backend-client (service account para Admin API) ────────────────
echo ""
echo "Verificando client 'backend-client'..."
BC_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/clients?clientId=backend-client" \
  -H "$AUTH" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -n "$BC_ID" ]; then
  echo "Client 'backend-client' já existe, pulando"
else
  echo "Criando client 'backend-client'..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_BASE/admin/realms/$REALM/clients" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"backend-client\",
      \"enabled\": true,
      \"protocol\": \"openid-connect\",
      \"publicClient\": false,
      \"secret\": \"$BACKEND_CLIENT_SECRET\",
      \"serviceAccountsEnabled\": true,
      \"standardFlowEnabled\": false,
      \"directAccessGrantsEnabled\": false
    }")

  if [ "$STATUS" = "201" ]; then
    echo "Client 'backend-client' criado"
    BC_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/clients?clientId=backend-client" \
      -H "$AUTH" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  else
    echo "Resposta inesperada ao criar backend-client: $STATUS"
  fi
fi

# Atribuir role manage-users ao service account do backend-client
SA_USER_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/clients/$BC_ID/service-account-user" \
  -H "$AUTH" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

RM_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/clients?clientId=realm-management" \
  -H "$AUTH" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

MANAGE_USERS_ROLE=$(curl -s "$KC_BASE/admin/realms/$REALM/clients/$RM_ID/roles/manage-users" \
  -H "$AUTH")

curl -s -o /dev/null -X POST \
  "$KC_BASE/admin/realms/$REALM/users/$SA_USER_ID/role-mappings/clients/$RM_ID" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "[$MANAGE_USERS_ROLE]"

echo "Role 'manage-users' atribuída ao service account de 'backend-client'"

# ── 6. Criar realm roles ────────────────────────────────────────────────────
echo ""
echo "🎭 Criando realm roles..."
for ROLE in admin advogado estagiario; do
  ROLE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KC_BASE/admin/realms/$REALM/roles/$ROLE" \
    -H "$AUTH")

  if [ "$ROLE_STATUS" = "200" ]; then
    echo "Role '$ROLE' já existe"
  else
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_BASE/admin/realms/$REALM/roles" \
      -H "$AUTH" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"$ROLE\"}")

    if [ "$STATUS" = "201" ]; then
      echo "Role '$ROLE' criada"
    else
      echo "Role '$ROLE': resposta $STATUS"
    fi
  fi
done

# ── 7. Criar usuário de teste ───────────────────────────────────────────────
echo ""
echo "Verificando usuário de teste '$TEST_USER'..."
EXISTING_USER_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/users?username=$TEST_USER&exact=true" \
  -H "$AUTH" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -n "$EXISTING_USER_ID" ]; then
  echo "Usuário '$TEST_USER' já existe, pulando"
else
  echo "Criando usuário de teste '$TEST_USER'..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_BASE/admin/realms/$REALM/users" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"$TEST_USER\",
      \"email\": \"$TEST_USER\",
      \"firstName\": \"Admin\",
      \"lastName\": \"Teste\",
      \"enabled\": true,
      \"emailVerified\": true,
      \"credentials\": [{
        \"type\": \"password\",
        \"value\": \"$TEST_PASS\",
        \"temporary\": false
      }],
      \"requiredActions\": []
    }")

  if [ "$STATUS" = "201" ]; then
    echo "Usuário '$TEST_USER' criado (senha: $TEST_PASS)"
  else
    echo "Resposta inesperada ao criar usuário: $STATUS"
  fi
fi

# ── 8. Atribuir role "admin" ao usuário ─────────────────────────────────────
echo ""
echo "Atribuindo role 'admin' ao usuário..."

# Buscar ID do usuário
USER_RESP=$(curl -s "$KC_BASE/admin/realms/$REALM/users?username=$TEST_USER&exact=true" \
  -H "$AUTH" 2>/dev/null || echo "[]")

USER_ID=$(echo "$USER_RESP" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -z "$USER_ID" ]; then
  echo "Não foi possível encontrar o usuário '$TEST_USER' para atribuir a role"
else
  # Buscar representação da role "admin"
  ROLE_JSON=$(curl -s "$KC_BASE/admin/realms/$REALM/roles/admin" -H "$AUTH" 2>/dev/null || echo "")

  if [ -n "$ROLE_JSON" ] && echo "$ROLE_JSON" | grep -q "name"; then
    # Atribuir role ao usuário
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$KC_BASE/admin/realms/$REALM/users/$USER_ID/role-mappings/realm" \
      -H "$AUTH" \
      -H "Content-Type: application/json" \
      -d "[$ROLE_JSON]")

    if [ "$STATUS" = "204" ]; then
      echo "Role 'admin' atribuída ao usuário '$TEST_USER'"
    else
      echo "Resposta ao atribuir role: $STATUS (pode já estar atribuída)"
    fi
  else
    echo "Não foi possível obter a role 'admin'"
  fi
fi

# ── Resumo ──────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "Keycloak configurado com sucesso!"
echo ""
echo "  Realm:         $REALM"
echo "  Client ID:     $CLIENT_ID"
echo "  Client Type:   public"
echo "  Usuário:       $TEST_USER"
echo "  Senha:         $TEST_PASS"
echo "  Role:          admin"
echo "════════════════════════════════════════════"
echo ""
