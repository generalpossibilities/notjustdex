.PHONY: help bootstrap analyze test gen clean dev up down lint

help:
	@echo 'DexChats monorepo commands:'
	@echo '  make bootstrap   - Install all Dart/Flutter dependencies via Melos'
	@echo '  make analyze     - Run Dart analyzer across all packages'
	@echo '  make test        - Run all Dart tests'
	@echo '  make test:go     - Run all Go tests'
	@echo '  make gen         - Regenerate all code (protos + freezed)'
	@echo '  make clean       - Clean all build artifacts'
	@echo '  make dev         - Start all services via docker-compose'
	@echo '  make stop        - Stop all services'
	@echo '  make lint        - Run all linters'

bootstrap:
	dart pub global activate melos
	melos bootstrap

analyze:
	melos run analyze

test:
	melos run test

test:go:
	go test ./services/...

gen:
	melos run gen

clean:
	melos clean
	rm -rf apps/mobile/build apps/web/build

dev:
	docker compose up --build -d

stop:
	docker compose down

lint: analyze
	golangci-lint run ./services/...
