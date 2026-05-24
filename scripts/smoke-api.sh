#!/usr/bin/env bash

# Cores para o output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0;0m' # No Color
BLUE='\033[0;34m'

API_URL="http://localhost:8000"

echo -e "${BLUE}=== Iniciando Teste de Fumaça da API (Smoke Test) ===${NC}"

# 1. Verificar se o jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERRO] O utilitário 'jq' é necessário para rodar este script. Instale-o com 'sudo apt install jq'.${NC}"
    exit 1
fi

# Função auxiliar para verificar erros
assert_status() {
    local status=$1
    local expected=$2
    local message=$3
    if [ "$status" -eq "$expected" ]; then
        echo -e "${GREEN}[OK] $message (Status $status)${NC}"
    else
        echo -e "${RED}[FALHA] $message (Esperava $expected, obteve $status)${NC}"
        exit 1
    fi
}

# Gerar identificadores únicos para evitar conflitos de banco de dados
RAND_ID=$((RANDOM % 90000 + 10000))
TEST_CPF="000.000.000-${RAND_ID: -2}"
TEST_CNJ="${RAND_ID}99-99.2026.8.26.0000"

# --- 1. HEALTH CHECKS ---
echo -e "\n${BLUE}--- Testando Health Checks ---${NC}"

# GET /health
response_health=$(curl -s -w "%{http_code}" -o response.json "${API_URL}/health")
status_health=$(echo "$response_health" | tail -c 4)
assert_status "$status_health" 200 "Health Check Geral"
status_val=$(jq -r '.status' response.json)
if [ "$status_val" == "ok" ]; then
    echo -e "${GREEN}[OK] Payload do Health Check Geral válido${NC}"
else
    echo -e "${RED}[FALHA] Payload do Health Check Geral inválido: $status_val${NC}"
    exit 1
fi

# GET /health/db
response_db=$(curl -s -w "%{http_code}" -o response.json "${API_URL}/health/db")
status_db=$(echo "$response_db" | tail -c 4)
assert_status "$status_db" 200 "Health Check do Banco de Dados"
db_status=$(jq -r '.database' response.json)
if [ "$db_status" == "connected" ]; then
    echo -e "${GREEN}[OK] Conectividade com o banco de dados activa${NC}"
else
    echo -e "${RED}[FALHA] Banco de dados desconectado: $db_status${NC}"
    exit 1
fi


# --- 2. CLIENTES CRUD ---
echo -e "\n${BLUE}--- Testando Fluxo de Clientes ---${NC}"

# POST /clientes/ (Criar)
client_payload="{\"nome_razao_social\": \"Cliente Teste Smoke\", \"cpf_cnpj\": \"${TEST_CPF}\", \"telefone\": \"11900000000\", \"email\": \"smoke@teste.com\"}"
response_post_client=$(curl -s -w "%{http_code}" -o response.json -X POST "${API_URL}/clientes/" \
    -H "Content-Type: application/json" -d "$client_payload")
status_post_client=$(echo "$response_post_client" | tail -c 4)
assert_status "$status_post_client" 201 "Criação de Cliente"

CLIENT_ID=$(jq '.id' response.json)
echo -e "${GREEN}[OK] Cliente criado com ID: $CLIENT_ID (CPF: $TEST_CPF)${NC}"

# GET /clientes/{id} (Buscar)
response_get_client=$(curl -s -w "%{http_code}" -o response.json "${API_URL}/clientes/${CLIENT_ID}")
status_get_client=$(echo "$response_get_client" | tail -c 4)
assert_status "$status_get_client" 200 "Busca de Cliente criado"


# --- 3. PROCESSOS CRUD ---
echo -e "\n${BLUE}--- Testando Fluxo de Processos ---${NC}"

# POST /processos/ (Criar)
processo_payload="{\"numero_cnj\": \"${TEST_CNJ}\", \"tribunal\": \"TJSP\", \"partes\": \"Smoke vs. Banco\", \"data_abertura\": \"2026-05-24T00:00:00\", \"status\": \"ativo\", \"favorito\": false, \"cliente_id\": $CLIENT_ID}"
response_post_processo=$(curl -s -w "%{http_code}" -o response.json -X POST "${API_URL}/processos/" \
    -H "Content-Type: application/json" -d "$processo_payload")
status_post_processo=$(echo "$response_post_processo" | tail -c 4)
assert_status "$status_post_processo" 201 "Criação de Processo"

PROCESSO_ID=$(jq '.id' response.json)
echo -e "${GREEN}[OK] Processo criado com ID: $PROCESSO_ID (CNJ: $TEST_CNJ)${NC}"

# PATCH /processos/{id}/favoritar (Favoritar)
response_patch_fav=$(curl -s -w "%{http_code}" -o response.json -X PATCH "${API_URL}/processos/${PROCESSO_ID}/favoritar")
status_patch_fav=$(echo "$response_patch_fav" | tail -c 4)
assert_status "$status_patch_fav" 200 "Favoritar Processo"
fav_val=$(jq '.favorito' response.json)
if [ "$fav_val" == "true" ]; then
    echo -e "${GREEN}[OK] Processo favoritado com sucesso${NC}"
else
    echo -e "${RED}[FALHA] Processo não favoritou: $fav_val${NC}"
    exit 1
fi


# --- 4. LEADS CRUD ---
echo -e "\n${BLUE}--- Testando Fluxo de Leads ---${NC}"

# POST /leads/ (Criar)
lead_payload='{"nome": "Lead Smoke", "email": "lead@smoke.com", "telefone": "11911112222", "mensagem": "Mensagem de teste do smoke script"}'
response_post_lead=$(curl -s -w "%{http_code}" -o response.json -X POST "${API_URL}/leads/" \
    -H "Content-Type: application/json" -d "$lead_payload")
status_post_lead=$(echo "$response_post_lead" | tail -c 4)
assert_status "$status_post_lead" 201 "Criação de Lead"
LEAD_ID=$(jq '.id' response.json)
echo -e "${GREEN}[OK] Lead criado com ID: $LEAD_ID${NC}"


# --- 5. LIMPEZA DOS DADOS ---
echo -e "\n${BLUE}--- Limpando dados de teste ---${NC}"

# DELETE /processos/{id}
response_del_proc=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "${API_URL}/processos/${PROCESSO_ID}")
assert_status "$(echo "$response_del_proc" | tail -c 4)" 204 "Remoção de Processo de Teste"

# DELETE /clientes/{id}
response_del_client=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "${API_URL}/clientes/${CLIENT_ID}")
assert_status "$(echo "$response_del_client" | tail -c 4)" 204 "Remoção de Cliente de Teste"

# DELETE /leads/{id}
response_del_lead=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "${API_URL}/leads/${LEAD_ID}")
assert_status "$(echo "$response_del_lead" | tail -c 4)" 204 "Remoção de Lead de Teste"

# Remover arquivo temporário
rm -f response.json

echo -e "\n${GREEN}===============================================${NC}"
echo -e "${GREEN}  TODOS OS TESTES DE FUMAÇA PASSARAM COM SUCESSO!${NC}"
echo -e "${GREEN}===============================================${NC}"
exit 0
