#!/usr/bin/env bash
set -e

# Default settings
SCENARIO="all"
DOWN_ON_EXIT=false
BASE_URL="http://localhost:8000"
COMPOSE_FILE="starter-kit/docker-compose.yml"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --down)
      DOWN_ON_EXIT=true
      shift
      ;;
    --scenario)
      SCENARIO="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./run.sh [SCENARIO] [--down] [--base-url URL]"
      echo "Options:"
      echo "  SCENARIO        Scenario to run (default: 'all', options: happy, gateway-retry, double-tap, abandoned, resume, out-of-order, bad-input, slow)"
      echo "  --down          Tear down Docker containers after execution"
      echo "  --base-url URL  Base URL for USSD service (default: http://localhost:8000)"
      exit 0
      ;;
    *)
      if [[ "$1" != -* ]]; then
        SCENARIO="$1"
      else
        echo "Unknown option: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

cleanup() {
  if [ "$DOWN_ON_EXIT" = true ]; then
    echo "Tearing down Docker containers..."
    docker compose -f "$COMPOSE_FILE" down
  fi
}
trap cleanup EXIT

echo "Starting Docker Compose services..."
docker compose -f "$COMPOSE_FILE" up -d --build

echo "Waiting for services to become ready..."
until docker compose -f "$COMPOSE_FILE" ps --format json | grep -q '"Health": *"healthy"' || \
      curl -s "$BASE_URL/health" > /dev/null 2>&1; do
  echo "Waiting for services to be healthy..."
  sleep 2
done

echo "Services are ready!"
echo "Running USSD gateway driver scenario(s): $SCENARIO"

python3 starter-kit/ussd-gateway/driver.py --base-url "$BASE_URL" --scenario "$SCENARIO"
