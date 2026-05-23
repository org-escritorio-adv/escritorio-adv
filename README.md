# Escritório Adv

Sistema web voltado a **escritórios de advocacia**. 

## Stack

| Camada    | Tecnologia                                      |
|----------|--------------------------------------------------|
| Backend  | FastAPI, Uvicorn, SQLAlchemy, psycopg2-binary   |
| Frontend | React 18, Vite 5                                |
| Banco    | PostgreSQL 15 (imagem Alpine)                   |
| Orquestração | Docker Compose                              |

## Estrutura do repositório

```
escritorio-adv/
├── backend/           # API FastAPI
│   ├── app/
│   │   ├── main.py    # Rotas e app FastAPI
│   │   └── db/        # Engine, sessão SQLAlchemy
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/          # SPA React (Vite)
│   ├── src/
│   ├── Dockerfile
│   └── package.json
├── docker-compose.yml # Postgres + backend + frontend
├── .env.example       # Exemplo de variáveis (dev local)
└── postgres/          # Dados do Postgres (volume local, não versionado)
```

## Clonar repositório

```
git clone --recurse-submodules https://github.com/org-escritorio-adv/escritorio-adv.git
```

## Pré-requisitos

- **Docker** e **Docker Compose** 
- Portas livres na máquina: **5432** (Postgres), **8000** (API), **3000** (frontend)

### Possíveis Problemas

Se aparecer `bind: address already in use` na porta **5432**, outro serviço (Postgres local, outro container, etc.) já está usando essa porta. Opções:

1. Parar o serviço que ocupa a 5432, ou  
2. Alterar o mapeamento no `docker-compose.yml`, por exemplo `"5433:5432"`, e usar `localhost:5433` em ferramentas externas. **Dentro** da rede do Compose, o backend continua acessando o host `postgres` na porta **5432**.

## Como executar

Na raiz do repositório:

```bash
docker-compose up --build
```

Na primeira execução as imagens são construídas; nas seguintes, `docker-compose up` costuma ser suficiente.

Para rodar em segundo plano:

```bash
docker-compose up -d --build
```

Para parar:

```bash
docker-compose down
```

(Opcional: `docker-compose down -v` remove volumes nomeados; a pasta `./postgres` no disco continua até você apagá-la manualmente.)

## O que acessar depois de subir

| Recurso        | URL |
|----------------|-----|
| Documentação da API (Swagger) | http://localhost:8000/docs |
| Health da API   | http://localhost:8000/health |
| Health + banco  | http://localhost:8000/health/db |
| Frontend (Vite) | http://localhost:3000 |

## Como executar o Smoke de Teste

Instale o jq se não possuir:

```bash
sudo apt install jq
```

Torne o arquivo executavel e execute:

```bash
chmod +x scripts/smoke-api.sh
./scripts/smoke-api.sh
```


O endpoint `/health/db` executa `SELECT 1` no PostgreSQL e confirma que a API alcança o banco usando a `DATABASE_URL` definida no Compose.

## Variáveis de ambiente

- No **Docker Compose**, a `DATABASE_URL` do backend está definida para o serviço `postgres`.
- Para rodar o **backend fora do Docker** com o Postgres do Compose exposto em `localhost`, copie `.env.example` para `.env` na pasta do backend (ou exporte a variável) e ajuste se mudar usuário, senha, banco ou porta publicada.

Credenciais padrão do Postgres neste projeto (apenas para desenvolvimento):

- Usuário / senha / banco: `org-escritorio-adv`

---

*Projeto em construção; o README deve ser atualizado conforme novas funcionalidades forem adicionadas.*
