# ── build ────────────────────────────────────────────────────
FROM golang:1.26-alpine AS build

WORKDIR /src

# แยก layer ของ dependency ออกจากโค้ด — แก้โค้ดแล้ว build ใหม่เร็วขึ้นมาก
COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
        -ldflags="-s -w -X main.version=${VERSION}" \
        -o /out/api ./cmd/api \
 && CGO_ENABLED=0 GOOS=linux go build \
        -ldflags="-s -w -X main.version=${VERSION}" \
        -o /out/worker ./cmd/worker

# ── runtime ──────────────────────────────────────────────────
FROM alpine:3.21

# ca-certificates จำเป็นสำหรับเรียก HTTPS ไป TikTok / OpenAI / R2
# tzdata จำเป็นเพราะ scheduler ต้องคำนวณเวลาตาม timezone ของผู้ใช้
RUN apk add --no-cache ca-certificates tzdata \
 && adduser -D -u 10001 app

WORKDIR /app
COPY --from=build /out/api    /app/api
COPY --from=build /out/worker /app/worker

USER app
EXPOSE 8080

CMD ["/app/api"]
