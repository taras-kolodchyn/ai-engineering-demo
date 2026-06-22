SHELL := /bin/sh

COMPOSE_WAIT_TIMEOUT ?= 180
COMPOSE_DOWN_TIMEOUT ?= 30

.PHONY: help init pull up down restart logs ps config check doctor urls smoke demo load ingest rag codex-demo drill clean

help:
	@printf '%s\n' \
		'Targets:' \
		'  make init     Copy .env.example to .env when .env does not exist' \
		'  make pull     Pull all compose images' \
		'  make up       Start the full stack and wait for healthy services' \
		'  make down     Stop the full stack without deleting volumes' \
		'  make restart  Restart the stack' \
		'  make logs     Follow logs for all services' \
		'  make ps       Show service status' \
		'  make config   Validate and render docker compose configuration' \
		'  make check    Run static repository checks' \
		'  make doctor   Run local preflight checks for the demo machine' \
		'  make urls     Print local service URLs and demo credentials' \
		'  make smoke    Run local endpoint smoke checks' \
		'  make demo     Start the stack and run a lecture demo request' \
		'  make load     Generate demo LiteLLM traffic and logs' \
		'  make ingest   Ingest sample Markdown knowledge into pgvector' \
		'  make rag      Ask a sample RAG question through LiteLLM' \
		'  make codex-demo  Ask the Rust Codex RAG demo service' \
		'  make drill    Run a controlled LiteLLM outage/recovery drill' \
		'  make clean    Stop the stack and delete compose volumes'

init:
	@test -f .env || cp .env.example .env

pull:
	docker compose pull --ignore-buildable

up: init
	docker compose up --detach --remove-orphans --wait --wait-timeout $(COMPOSE_WAIT_TIMEOUT)

down:
	docker compose down --remove-orphans --timeout $(COMPOSE_DOWN_TIMEOUT)

restart: down up

logs:
	docker compose logs -f --tail=150

ps:
	docker compose ps

config:
	docker compose config

check:
	./scripts/check.sh

doctor:
	./scripts/doctor.sh

urls:
	./scripts/print-urls.sh

smoke:
	./scripts/smoke-test.sh

demo: up
	./scripts/demo-request.sh

load: up
	./scripts/generate-load.sh

ingest: up
	./scripts/ingest-knowledge.sh

rag: ingest
	./scripts/rag-query.sh

codex-demo: ingest
	./scripts/codex-rag-demo.sh

drill: up
	./scripts/failure-drill.sh

clean:
	docker compose down -v --remove-orphans --timeout $(COMPOSE_DOWN_TIMEOUT)
