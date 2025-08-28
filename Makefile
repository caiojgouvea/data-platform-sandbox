# ====== Configs ======
PROJECT := datalab
FILES_CORE := -f compose/minio.yml -f compose/postgres.yml
FILES_AIRFLOW := $(FILES_CORE) -f compose/redis.yml -f compose/airflow.yml
FILES_SPARK := -f compose/spark.yml
FILES_NOTEBOOK := $(FILES_SPARK) -f compose/jupyter.yml
NETWORK := datalab-net
ENVFILE := .env
PYSPARK ?= 3.5.2
.DEFAULT_GOAL := help
NOTEBOOK_SVC ?= datalab-jupyter-notebook
SERVICE_SPARK ?= spark-master
# URL do master do cluster Standalone (sobrescreva com MASTER=local[*] p/ rodar local)
MASTER ?= spark://spark-master:7077

# ====== Tarefas ======

help: ## Mostra esta ajuda
	@echo "Comandos disponíveis:"
	@echo "  make network             - cria a rede docker '$(NETWORK)' (ignora se já existir)"
	@echo "  make env                 - gera .env se não existir"
	@echo "  make up-core             - sobe MinIO + Postgres"
	@echo "  make down-core           - derruba MinIO + Postgres (mantém dados)"
	@echo "  make ps-core             - status dos containers core"
	@echo "  make up-airflow          - sobe Redis + Airflow (depende do core)"
	@echo "  make ps-airflow          - status dos serviços do Airflow"
	@echo "  make logs-airflow        - segue logs do webserver e scheduler"
	@echo "  make down-airflow        - derruba serviços do Airflow (mantém dados)"
	@echo "  make up-spark            - sobe Spark master + worker"
	@echo "  make ps-spark            - status dos serviços Spark"
	@echo "  make logs-spark          - segue logs do Spark master e worker"
	@echo "  make down-spark          - derruba serviços Spark (mantém dados)"
	@echo "  make recreate-spark      - recria master/worker"
	@echo "  make submit              - submete um .py (ver variáveis: JOB, MASTER, ARGS)"
	@echo "  make submit-local        - atalho p/ submit em local[*]"
	@echo "  make up-notebook         - sobe Jupyter na mesma rede do Spark"
	@echo "  make ps-notebook         - status do Jupyter"
	@echo "  make logs-notebook       - logs do Jupyter"
	@echo "  make down-notebook       - derruba Jupyter"
	@echo "  make open-notebook       - abre http://localhost:8888/lab"
	@echo "  make down-all            - derruba tudo (mantém dados)"
	@echo "  make stop-all            - para tudo (mantém dados)"
	@echo "  make restart-airflow     - reinicia webserver/scheduler/worker"
	@echo "  make all                 - sobe tudo (core + airflow, sem init)"
	@echo "  make start               - sobe tudo (core + airflow, sem init, uso diário)"

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

ps-airflow: ## Status do Airflow
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) ps

logs-airflow: ## Logs do webserver e scheduler
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) logs -f airflow-webserver airflow-scheduler

down-airflow: ## Derruba serviços do Airflow (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) down

# ====== Spark ======
up-spark: network env ## Sobe Spark master + worker
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) up -d

ps-spark: ## Status dos serviços Spark
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) ps

logs-spark: ## Logs do Spark master e worker
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) logs -f spark-master spark-worker

down-spark: ## Derruba serviços Spark (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) down

recreate-spark: network env ## Recria spark-master/worker com --force-recreate
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) up -d --force-recreate

submit: ## make submit JOB=src/dps/jobs/hello_world.py MASTER=local[*] ou MASTER=spark://spark-master:7077
	@docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) run --rm \
	  -v $(shell dirname $(realpath $(JOB))):/app \
	  -v $$HOME/.ivy2:/tmp/ivy2 \
	  -w /app \
	  $(SERVICE_SPARK) \
	  spark-submit --master $(MASTER) /app/$(shell basename $(JOB)) $(ARGS)

submit-local: ## Atalho: make submit-local JOB=src/dps/jobs/hello_world.py
	$(MAKE) submit JOB=$(JOB) MASTER=local[*] ARGS=$(ARGS)

# ====== Notebook ======

up-notebook: network env ## Sobe Jupyter na mesma rede do Spark
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_NOTEBOOK) up -d --build $(NOTEBOOK_SVC)
	@echo "=> VS Code: Existing Jupyter Server em http://127.0.0.1:8888"

ps-notebook:
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_NOTEBOOK) ps

logs-notebook:
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_NOTEBOOK) logs -f $(NOTEBOOK_SVC)

down-notebook:
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_NOTEBOOK) down $(NOTEBOOK_SVC) || true
# ====== Meta targets ======
down-all: ## Derruba tudo (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) down || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) down || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) down || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_NOTEBOOK) down || true

stop-all: ## Para tudo (mantém dados)
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) stop || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_CORE) stop || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_SPARK) stop || true
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_NOTEBOOK) stop || true

restart-airflow: ## Reinicia webserver/scheduler/worker
	docker compose --env-file $(ENVFILE) -p $(PROJECT) $(FILES_AIRFLOW) restart airflow-webserver airflow-scheduler airflow-worker

all: up-core up-airflow ## Sobe todo o stack (sem init)

start: up-core up-airflow ## Sobe todo o stack (sem init, uso diário)
