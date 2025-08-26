# ====== Configs ======
PROJECT := datalab
FILES_CORE := -f compose/minio.yml -f compose/postgres.yml
FILES_AIRFLOW := $(FILES_CORE) -f compose/redis.yml -f compose/airflow.yml
NETWORK := datalab-net
ENVFILE := .env

.DEFAULT_GOAL := help

# ====== Tarefas ======

help: ## Mostra esta ajuda
	@echo "Comandos disponíveis:"
	@echo "  make network         - cria a rede docker '$(NETWORK)' (ignora se já existir)"
	@echo "  make up-core         - sobe MinIO + Postgres"
	@echo "  make down-core       - derruba MinIO + Postgres (mantém dados)"
	@echo "  make ps-core         - status dos containers core"
	@echo "  make up-airflow      - sobe Redis + Airflow (depende do core)"
	@echo "  make init-airflow    - inicializa DB do Airflow e cria usuário admin"
	@echo "  make ps-airflow      - status dos serviços do Airflow"
	@echo "  make logs-airflow    - segue logs do webserver e scheduler"
	@echo "  make down-airflow    - derruba serviços do Airflow (mantém dados)"
	@echo "  make down-all        - derruba tudo (mantém dados)"
	@echo "  make stop-all        - para tudo (mantém dados)"
	@echo "  make restart-airflow - reinicia webserver/scheduler/worker"
	@echo "  make all             - sobe tudo (core + airflow, com init)"
	@echo "  make start           - sobe tudo (core + airflow, sem init)"
	@echo "  make env             - gera .env se não existir"

network: ## Cria rede externa compartilhada
	-@docker network create $(NETWORK) >/dev/null 2>&1 || true

env: ## Gera .env a partir de .env.example se não existir
	@if [ ! -f $(ENVFILE) ]; then cp .env.example $(ENVFILE); echo "=> .env criado a partir de .env.example"; else echo "=> .env já existe"; fi

up-core: network env ## Sobe MinIO + Postgres
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) up -d

down-core: ## Derruba MinIO + Postgres (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) down

ps-core: ## Mostra status do core
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) ps

up-airflow: network env ## Sobe Redis + Airflow (exige core ativo)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) up -d

init-airflow: ## Inicializa DB e cria usuário admin (rodar 1x ou após reset)
	@docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) run --rm airflow-init bash -c "\
	if airflow users list | grep -q '${_AIRFLOW_WWW_USER_USERNAME}'; then \
		echo 'Usuário ${_AIRFLOW_WWW_USER_USERNAME} já existe. Pulando criação de usuário.'; \
	else \
		airflow db upgrade && \
		airflow users create \
			--username '${_AIRFLOW_WWW_USER_USERNAME}' \
			--password '${_AIRFLOW_WWW_USER_PASSWORD}' \
			--firstname Admin \
			--lastname User \
			--role Admin \
			--email admin@example.com; \
	fi"

ps-airflow: ## Status do Airflow
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) ps

logs-airflow: ## Logs do webserver e scheduler
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) logs -f airflow-webserver airflow-scheduler

down-airflow: ## Derruba serviços do Airflow (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) down

down-all: ## Derruba tudo (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) down || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) down || true

stop-all: ## Para tudo (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) stop || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) stop || true

restart-airflow: ## Reinicia webserver/scheduler/worker
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) restart airflow-webserver airflow-scheduler airflow-worker

# ====== Meta targets ======

all: up-core init-airflow up-airflow ## Sobe todo o stack (com init)

start: up-core up-airflow ## Sobe todo o stack (sem init, uso diário)
