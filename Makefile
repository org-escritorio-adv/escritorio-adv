.PHONY: up down build clean test logs shell-backend shell-frontend help

help:
	@echo "Comandos disponíveis:"
	@echo "  make up              - Inicia todos os containers em background"
	@echo "  make down            - Para todos os containers"
	@echo "  make build           - Reconstrói e inicia os containers"
	@echo "  make clean           - Para containers e DELETA OS VOLUMES (incluindo o banco de dados)"
	@echo "  make test-all        - Executa todos os testes (backend e frontend)"
	@echo "  make test-backend-unit - Executa os testes unitários do backend"
	@echo "  make test-integration- Executa os testes de integração do backend"
	@echo "  make test-frontend-unit- Executa os testes unitários do frontend"
	@echo "  make test-selenium   - Executa os testes automatizados do selenium"
	@echo "  make logs            - Mostra os logs de todos os containers"
	@echo "  make shell-backend   - Abre o terminal dentro do container do backend"
	@echo "  make shell-frontend  - Abre o terminal dentro do container do frontend"

up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose up -d --build

clean:
	@echo "ATENÇÃO: Isso deletará o banco de dados e todos os volumes!"
	docker compose down -v

test-backend-unit:
	docker compose exec -e PYTHONPATH=/app backend pytest src/

test-integration:
	docker compose exec -e PYTHONPATH=/app backend pytest tests/integration/

test-frontend-unit:
	docker compose exec frontend npm run test:run -- "src/**/*.spec.tsx" "src/**/*.spec.ts"

test-selenium:
	docker compose exec frontend sh -c 'for file in src/tests/*.test.js; do echo "Rodando $$file..."; node "$$file"; done'

test-all: test-backend-unit test-integration test-frontend-unit test-selenium

logs:
	docker compose logs -f

shell-backend:
	docker compose exec backend /bin/sh

shell-frontend:
	docker compose exec frontend /bin/sh
