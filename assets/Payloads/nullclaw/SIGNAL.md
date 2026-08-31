# Signal Deployment

Run nullclaw as a Signal chatbot using Docker Compose and a local `signal-cli` container.

## Architecture

```
Signal app  <-->  signal-cli container (:8080)  <-->  nullclaw gateway (:3000)
```

## Setup

### 1. Register or link a Signal account

```bash
docker compose -f docker-compose.yml -f docker-compose.signal.yml up -d signal-cli
docker compose -f docker-compose.yml -f docker-compose.signal.yml exec signal-cli signal-cli link -n nullclaw
```

Scan the QR code in Signal (Settings -> Linked Devices -> Link New Device), then stop the `signal-cli` container.

### 2. Create local config files

Create `.env.signal` with your secrets:

```bash
OPENROUTER_API_KEY=...
SIGNAL_ACCOUNT=+1...
SIGNAL_RECIPIENT=+1...   # or uuid:...
```

Create `config.signal.json` (example):

```json
{
  "models": {
    "providers": {
      "openrouter": {
        "api_key": "YOUR_OPENROUTER_API_KEY"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/anthropic/claude-sonnet-4"
      }
    }
  },
  "channels": {
    "signal": {
      "accounts": {
        "main": {
          "http_url": "http://signal-cli:8080",
          "account": "+10000000000",
          "allow_from": ["+10000000001"],
          "group_policy": "allowlist",
          "ignore_attachments": true,
          "ignore_stories": true
        }
      }
    }
  },
  "gateway": {
    "port": 3000,
    "host": "0.0.0.0",
    "require_pairing": false
  }
}
```

Keep `http_url` as `http://signal-cli:8080` for Docker networking.

### 3. Build nullclaw image

```bash
DOCKER_BUILDKIT=0 docker build -t nullclaw:latest .
```

## Runtime modes (env-gated)

To prevent regressions, Docker defaults to the legacy JSON-RPC mode:

- `SIGNAL_USE_REST_API=0` (default)
- `SIGNAL_CLI_MODE=json-rpc` (default)

To opt into `signal-cli-rest-api` REST mode explicitly:

```bash
export SIGNAL_USE_REST_API=1
export SIGNAL_CLI_MODE=normal
```

Then start as usual.

## Usage

### Start

```bash
docker compose -f docker-compose.yml -f docker-compose.signal.yml --profile gateway up -d
```

### Stop

```bash
docker compose -f docker-compose.yml -f docker-compose.signal.yml --profile gateway down
```

### Logs

```bash
docker compose -f docker-compose.yml -f docker-compose.signal.yml --profile gateway logs -f
```

### Health checks

```bash
curl http://localhost:3000/health
curl -i http://localhost:8080/v1/health
```

## Cleanup

```bash
docker compose -f docker-compose.yml -f docker-compose.signal.yml --profile gateway down -v
docker rmi nullclaw:latest
docker rmi bbernhard/signal-cli-rest-api:latest
rm -rf ~/.local/share/signal-cli
rm -f .env.signal config.signal.json
```
