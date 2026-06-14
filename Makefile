.PHONY: up down build clean test logs shell-backend shell-frontend help

help:
	@echo "Comandos disponíveis:"
	@echo "  make up              - Inicia todos os containers em background"
	@echo "  make down            - Para todos os containers"
	@echo "  make build           - Reconstrói e inicia os containers"
	@echo "  make clean           - Para containers e DELETA OS VOLUMES (incluindo o banco de dados)"
	@echo "  make test            - Executa os testes do backend usando pytest"
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

test:
	docker compose exec backend pytest src/

logs:
	docker compose logs -f

shell-backend:
	docker compose exec backend /bin/sh

shell-frontend:
	docker compose exec frontend /bin/sh
