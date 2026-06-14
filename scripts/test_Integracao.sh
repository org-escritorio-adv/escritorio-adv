#!/usr/bin/env bash
set -euo pipefail
[[ -f ./.env ]] && source ./.env

BASE="http://localhost:8000"
KC_BASE="http://localhost:8080"
REALM="escritorio-adv"
CLIENT_ID="backend-api"
KC_ADMIN_USER="admin"
KC_ADMIN_PASS="admin"
TEST_USER="admin@escritorio.com"
TEST_PASS="admin123"
DATAJUD_API_KEY="${DATAJUD_API_KEY:-}"



PASS=0
FAIL=0

# ── Obter token JWT do Keycloak ─────────────────────────────────────────────
echo ""
echo "Obtendo token JWT do Keycloak..."

TOKEN=""
for attempt in $(seq 1 15); do
  TOKEN_RESPONSE=$(curl -s -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
    -d "client_id=$CLIENT_ID" \
    -d "username=$TEST_USER" \
    -d "password=$TEST_PASS" \
    -d "grant_type=password" 2>/dev/null || echo "")

  TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

  if [[ -n "$TOKEN" ]]; then
    echo "Token obtido com sucesso"
    break
  fi

  echo "  tentativa $attempt/15... (Keycloak pode estar iniciando)"
  sleep 3
done

if [[ -z "$TOKEN" ]]; then
  echo "Falha ao obter token do Keycloak após 15 tentativas"
  echo "   Última resposta: $TOKEN_RESPONSE"
  exit 1
fi
echo ""

# ── Helpers ─────────────────────────────────────────────────────────────────

assert_status() {
  local method="$1" url="$2" expected="$3"
  shift 3
  local extra_args=("$@")

  actual=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" \
    -H "Authorization: Bearer $TOKEN" \
    "${extra_args[@]}" "$url")

  if [[ "$actual" == "$expected" ]]; then
    echo "$method $url → $actual"
    PASS=$((PASS + 1))
  else
    echo "$method $url → $actual (expected $expected)"
    FAIL=$((FAIL + 1))
  fi
}

CREATED_ID=""
create_resource() {
  local ep="$1" payload="$2" expected="$3"
  
  local response
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$BASE/$ep/")
    
  local actual
  actual=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$d')
  
  if [[ "$actual" == "$expected" ]]; then
    echo "POST $BASE/$ep/ → $actual"
    PASS=$((PASS + 1))
    CREATED_ID=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")
  else
    echo "POST $BASE/$ep/ → $actual (expected $expected)"
    echo "  Response body: $body"
    FAIL=$((FAIL + 1))
    CREATED_ID=""
  fi
}

get_payload() {
  local ep="$1"
  local proc_id="$2"
  case "$ep" in
    processos)
      echo '{"numero_cnj": "0001234-56.2023.8.26.0000", "tribunal": "TJSP"}'
      ;;
    clientes)
      echo '{"nome_razao_social": "Cliente Teste", "cpf_cnpj": "123.456.789-00"}'
      ;;
    leads)
      echo '{"nome": "Lead site Teste", "email": "lead@site.com"}'
      ;;
    usuarios)
      echo '{"nome": "Novo Usuario", "email": "novo.user@escritorio.com", "senha": "senhaSegura123", "perfil": "advogado"}'
      ;;
    prazos)
      echo "{\"titulo\": \"Prazo Teste\", \"data_limite\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"processo_id\": $proc_id}"
      ;;
    tarefas)
      echo '{"titulo": "Tarefa Teste"}'
      ;;
    movimentacoes)
      echo "{\"data\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"descricao\": \"Movimentação de teste\", \"processo_id\": $proc_id}"
      ;;
  esac
}

echo "Smoke Tests — API REST (com autenticação Keycloak)"
echo "─────────────────────────────────────────────────────"

echo ""
echo "Health (sem auth)"
# Health check não requer autenticação
actual=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/")
if [[ "$actual" == "200" ]]; then
  echo "GET $BASE/ → $actual"
  PASS=$((PASS + 1))
else
  echo "GET $BASE/ → $actual (expected 200)"
  FAIL=$((FAIL + 1))
fi

# Cria processo pai persistente para relacionamentos
echo ""
echo "Criando processo base para relacionamentos..."
create_resource "processos" '{"numero_cnj": "9999999-99.2023.8.26.9999", "tribunal": "TJSP"}' 201
PROCESSO_ID="$CREATED_ID"

if [[ -z "$PROCESSO_ID" ]]; then
  echo "Falha ao criar processo base para relacionamentos. Abortando testes."
  exit 1
fi

ENDPOINTS=("processos" "clientes" "leads" "usuarios" "prazos" "tarefas" "movimentacoes")

for ep in "${ENDPOINTS[@]}"; do
  echo ""
  echo "/$ep"

  payload=$(get_payload "$ep" "$PROCESSO_ID")

  # CREATE
  create_resource "$ep" "$payload" 201
  
  if [[ -n "$CREATED_ID" ]]; then
    # LIST
    assert_status GET "$BASE/$ep/" 200

    # READ
    assert_status GET "$BASE/$ep/$CREATED_ID" 200

    # UPDATE
    assert_status PATCH "$BASE/$ep/$CREATED_ID" 200 \
      -H "Content-Type: application/json" \
      -d '{}'

    # DELETE
    assert_status DELETE "$BASE/$ep/$CREATED_ID" 204
  else
    echo "  Ignorando GET/PATCH/DELETE pois a criação falhou."
  fi
done

# Limpa processo base persistente
echo ""
echo "Limpando processo base..."
assert_status DELETE "$BASE/processos/$PROCESSO_ID" 204

echo ""
echo "/datajud (sem corpo — deve retornar 422)"

assert_status POST "$BASE/datajud/consultar" 422 \
  -H "Content-Type: application/json" \
  -d '{}'

assert_status POST "$BASE/datajud/importar" 422 \
  -H "Content-Type: application/json" \
  -d '{}'

# Testes que batem na API real do DataJud — só rodam se DATAJUD_API_KEY estiver disponível
if [[ -n "${DATAJUD_API_KEY:-}" ]]; then
  echo ""
  echo "/datajud (com API key — chamadas reais ao DataJud)"
  assert_status GET "$BASE/datajud/buscar/TJSP?numero_processo=40049132920258260309" 200
  assert_status GET "$BASE/datajud/recentes/TJSP" 200  
else
  echo ""
  echo "/datajud chamadas reais ignoradas (DATAJUD_API_KEY não definida no ambiente)"
fi

echo ""
echo "════════════════════════════"
echo "  Results: $PASS passed · $FAIL failed"
echo "════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

echo ""
echo "All smoke tests passed!"

