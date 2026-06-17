# Infra Vercel + Neon

Este Terraform automatiza o deploy do projeto exceto o Keycloak:

- Cria um Postgres no Neon.
- Cria o projeto backend FastAPI na Vercel usando `backend/`.
- Cria o projeto frontend Vite na Vercel usando `frontend/`.
- Configura deploy automatico pela branch `main`.
- Injeta `DATABASE_URL` no backend.
- Injeta `VITE_API_URL` e `VITE_KEYCLOAK_*` no frontend.
- Configura dominios customizados se forem informados.
- Usa `frontend/vercel.json` para redirecionar rotas client-side para `index.html`.

## Secrets necessarios

Exportar antes de rodar:

```bash
export VERCEL_API_TOKEN="<token-vercel>"
export NEON_API_KEY="<token-neon>"
```

O token da Vercel nao deve ser salvo em arquivo. Se o token anterior foi exposto, revogue e crie outro antes de aplicar.

## Configuracao

Criar o arquivo local:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` com:

- URL publica do Keycloak externo.
- `neon_org_id`, quando a API Neon exigir organizacao explicita.
- No plano free do Neon, `history_retention_seconds` fica em `21600`.
- Secret administrativo do Keycloak, se o reset de senha for usado.
- Dominio do frontend e backend, se houver.
- Chaves DataJud e Resend, se forem usadas em producao.

## Execucao

```bash
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Se o Terraform instalado pelo pacote do sistema falhar com erro de plugin como
`Unrecognized remote plugin message`, use um binario oficial da HashiCorp. Nesta
maquina, o pacote Kali `1.6.3-dev` falhou com os providers, enquanto o Terraform
oficial `1.9.8` validou a configuracao.

Cada push ou merge na `main` do repositorio `org-escritorio-adv/escritorio-adv` passa a disparar deploy automatico nos projetos conectados pela Vercel.

## Observacoes

- Conta pessoal Vercel usa `vercel_team = null`.
- O backend roda na Vercel como Python Function/FastAPI, nao via Docker Compose.
- O Keycloak continua fora da automacao. Este Terraform apenas passa as URLs e secrets dele para frontend/backend.
- Para Keycloak atras de ngrok/reverse proxy HTTPS, use `KC_PROXY_HEADERS=xforwarded`.
- `terraform.tfvars` e o state local nao devem ser versionados.
