.PHONY: help tidy build run worker test lint up down logs ps psql redis-cli genkey clean

help:
	@echo "tidy    - go mod tidy"
	@echo "build   - build ทั้ง api และ worker ลง ./bin"
	@echo "run     - รัน api บนเครื่อง (ต้อง up postgres/redis ก่อน)"
	@echo "worker  - รัน worker บนเครื่อง"
	@echo "test    - go test ./..."
	@echo "up      - docker compose up -d --build"
	@echo "down    - docker compose down"
	@echo "logs    - ตาม log ของ api + worker"
	@echo "psql    - เปิด psql เข้า postgres ใน compose"
	@echo "genkey  - สร้าง encryption key ใหม่"

tidy:
	go mod tidy

build:
	go build -o bin/api ./cmd/api
	go build -o bin/worker ./cmd/worker

run:
	go run ./cmd/api

worker:
	go run ./cmd/worker

test:
	go test ./... -race -count=1

lint:
	go vet ./...
	gofmt -l .

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f api worker

ps:
	docker compose ps

psql:
	docker compose exec postgres psql -U relaycontent -d relaycontent

redis-cli:
	docker compose exec redis redis-cli

genkey:
	go run ./cmd/genkey

clean:
	rm -rf bin out
