# TallyHo

Usage metering and billing dashboard built with Elixir, Phoenix, and LiveView.

## Prerequisites

- [mise](https://mise.jdx.dev/) (runtime version manager)
- PostgreSQL 17
- macOS (development)

## Setup

### 1. Install Erlang & Elixir

```bash
# mise reads .mise.toml and installs the pinned versions
mise install
```

Verify:

```bash
elixir --version
# Elixir 1.18.5 (compiled with Erlang/OTP 27)
```

### 2. Install PostgreSQL

```bash
brew install postgresql@17
brew services start postgresql@17
```

### 3. Start the app

```bash
mix setup        # install deps, create DB, run migrations
mix phx.server   # start at localhost:4000
```

Visit the dashboard in your browser:
- **Dashboard:** [http://localhost:4000/dashboard/cust_123](http://localhost:4000/dashboard/cust_123)

Or start inside IEx (interactive Elixir REPL + server):

```bash
iex -S mix phx.server
```

## Running Tests

```bash
mix test                       # run all unit and integration tests
mix precommit                  # compile warnings check + format + tests
```

## API Usage

### Ingest Usage Event

```bash
curl -X POST http://localhost:4000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust_123",
    "metric": "api_requests",
    "quantity": 2500,
    "idempotency_key": "evt_test_001"
  }'
```

**Supported Metrics & Pricing:**
- `api_requests`: $0.001 / request
- `storage_gb`: $0.05 / GB
- `compute_hours`: $0.10 / hour

**Responses:**
- `201 Created`: Event recorded and broadcast to LiveView over PubSub.
- `409 Conflict`: Duplicate `idempotency_key` — protects against double-billing.
- `422 Unprocessable Entity`: Validation failure with field errors.

## Troubleshooting

**`role "postgres" does not exist`** — Homebrew creates a role matching your macOS username, not `postgres`. Fix with:

```bash
createuser -s postgres
```

## Architecture

- **Web Layer:** Phoenix Endpoint, Router, and Controller for JSON API.
- **Real-Time UI:** Phoenix LiveView with `Phoenix.PubSub` and LiveView Streams.
- **Persistence:** Ecto schema with UUIDs (`binary_id`) and unique database index on `idempotency_key`.
- **Billing Engine:** Pure functional module using `Decimal` for exact arbitrary-precision arithmetic.

## Production Deployment (Fly.io)

- **Live URL:** [https://tallyho.fly.dev/dashboard/cust_123](https://tallyho.fly.dev/dashboard/cust_123)
- **Live Ingest API:** `POST https://tallyho.fly.dev/api/events`

### Deploying Your Own Instance

To deploy this project to your own Fly.io account:

1. **Install Fly CLI & Authenticate:**
   ```bash
   brew install flyctl
   fly auth login
   ```

2. **Launch Application & Provision Database:**
   ```bash
   fly launch --no-deploy
   ```
   - Choose a unique app name.
   - When prompted for Postgres, select Unmanaged / Development Postgres (single node) to remain within Fly's free tier.

3. **Deploy:**
   ```bash
   fly deploy
   ```
   - Database migrations run automatically during rollout via the `/app/bin/migrate` release command.
   - `fly.toml` is configured with `auto_stop_machines = 'stop'` and `min_machines_running = 0` so idle machines spin down to 0 for zero ongoing cost.



