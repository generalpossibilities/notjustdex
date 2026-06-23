.PHONY: help bootstrap analyze test gen clean dev stop lint

help:
	@echo 'NotJustDex monorepo commands:'
	@echo '  make bootstrap   - Install all Dart/Flutter dependencies via Melos'
	@echo '  make analyze     - Run Dart analyzer across all packages'
	@echo '  make test        - Run all Dart tests'
	@echo '  make gen         - Regenerate all code (protos + freezed)'
	@echo '  make clean       - Clean all build artifacts'
	@echo '  make dev         - Start chat relay via docker-compose'
	@echo '  make stop        - Stop all services'
	@echo '  make lint        - Run Dart analyzer'

bootstrap:
	dart pub global activate melos
	melos bootstrap

analyze:
	melos run analyze

test:
	melos run test

gen:
	melos run gen

clean:
	melos clean
	rm -rf apps/mobile/build apps/web/build

dev:
	docker compose up --build -d

stop:
	docker compose down

lint:
	melos run analyze
