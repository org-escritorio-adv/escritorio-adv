#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8000"
KC_BASE="http://localhost:8080"
REALM="escritorio-adv"
CLIENT_ID="backend-api"
CLIENT_SECRET="smoke-test-secret-key-001"
TEST_USER="admin@escritorio.com"
TEST_PASS="admin123"

PASS=0
FAIL=0

# ── Obter token JWT do Keycloak ─────────────────────────────────────────────
echo ""
echo "Obtendo token JWT do Keycloak..."

TOKEN_RESPONSE=$(curl -sf -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$TEST_USER" \
  -d "password=$TEST_PASS" \
  -d "grant_type=password" 2>&1) || {
  echo "Falha ao obter token do Keycloak"
  echo "   Resposta: $TOKEN_RESPONSE"
  exit 1
}

TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null) || {
  echo "Falha ao extrair access_token da resposta"
  echo "   Resposta: $TOKEN_RESPONSE"
  exit 1
}

echo "Token obtido com sucesso"
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
    ((PASS++))
  else
    echo "$method $url → $actual (expected $expected)"
    ((FAIL++))
  fi
}

echo "Smoke Tests — API REST (com autenticação Keycloak)"
echo "─────────────────────────────────────────────────────"

echo ""
echo "Health (sem auth)"
# Health check não requer autenticação
actual=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/")
if [[ "$actual" == "200" ]]; then
  echo "GET $BASE/ → $actual"
  ((PASS++))
else
  echo "GET $BASE/ → $actual (expected 200)"
  ((FAIL++))
fi

ENDPOINTS=(processos clientes leads usuarios prazos tarefas movimentacoes)

for ep in "${ENDPOINTS[@]}"; do
  echo ""
  echo "/$ep"

  # CREATE
  assert_status POST "$BASE/$ep/" 201 \
    -H "Content-Type: application/json" \
    -d '{}'

  # LIST
  assert_status GET "$BASE/$ep/" 200

  # READ (id=1, criado acima)
  assert_status GET "$BASE/$ep/1" 200

  # UPDATE
  assert_status PATCH "$BASE/$ep/1" 200 \
    -H "Content-Type: application/json" \
    -d '{}'

  # DELETE
  assert_status DELETE "$BASE/$ep/1" 204
done

echo ""
echo "/datajud (sem corpo / sem API key — deve retornar 4xx)"

assert_status POST "$BASE/datajud/consultar" 422 \
  -H "Content-Type: application/json" \
  -d '{}'

assert_status POST "$BASE/datajud/importar" 422 \
  -H "Content-Type: application/json" \
  -d '{}'

assert_status GET "$BASE/datajud/buscar/TJSP" 200

assert_status GET "$BASE/datajud/listar/TJSP" 200

echo ""
echo "════════════════════════════"
echo "  Results: $PASS passed · $FAIL failed"
echo "════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

echo ""
echo "All smoke tests passed!"
