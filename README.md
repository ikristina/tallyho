# TallyHo

Usage metering and billing dashboard built with Elixir, Phoenix, and LiveView.

![TallyHo Live Dashboard](priv/static/images/dashboard.png)

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

## Project Structure

```text
lib/
├── tallyho/
│   ├── billing/invoicer.ex    # Pure domain calculation & Decimal pricing engine
│   ├── usage.ex               # Usage context & PubSub broadcast wiring
│   └── usage/event.ex         # Ecto schema, UUIDs, & changeset validations
└── tallyho_web/
    ├── controllers/           # JSON API endpoint & 409 conflict handling
    └── live/dashboard_live.ex # Real-time LiveView dashboard & stream subscriber
```

## Architecture & Key Design Decisions

The application is structured around four core design decisions balancing financial safety, real-time performance, and operational cost:

### 1. Database-Enforced Idempotency (vs. Distributed Caching)
- **Decision:** Use UUIDv4 primary keys (`:binary_id`) and a PostgreSQL `UNIQUE INDEX` on `[:idempotency_key]`, translated by Ecto changesets into an explicit `409 Conflict`.
- **Why:** In usage metering and billing pipelines, duplicate event ingestion directly causes double-charging. While application-level caches (e.g., Redis `SETNX`) are fast, network partitions or process crashes risk split-brain duplicates. The relational database is the single ACID source of truth across all API workers.
- **Trade-off:** Rejects duplicate submissions with HTTP 409, requiring clients to handle replay errors explicitly rather than receiving a silent 200 replay.

### 2. Exact Sub-Cent Precision & Pure Domain Logic
- **Decision:** Unit prices and calculations use the `Decimal` library with string-based exact arbitrary precision (e.g., `"0.001"`/request). All cost aggregations and invoice computations live in `TallyHo.Billing.Invoicer` as a pure, database-unaware functional module.
- **Why:** IEEE 754 binary floating-point (`float`) causes rounding errors (`0.1 + 0.2 != 0.3`). Integer-cent representations fail when pricing micro-units at sub-cent rates. Decoupling math from Ecto makes domain logic 100% deterministic, instant to test without fixtures or DB transactions, and cleanly reusable across LiveView, CLI, and batch jobs.
- **Trade-off:** `Decimal` arithmetic functions (`Decimal.mult/2`, `Decimal.add/2`) are slightly more verbose than primitive math operators.

### 3. Server-Driven Real-Time UI (LiveView Streams + PubSub vs. SPA Polling)
- **Decision:** Real-time push updates via `Phoenix.PubSub` (`customer_usage:<id>`) directly into `TallyHoWeb.DashboardLive`, utilizing LiveView Streams (`phx-update="stream"`).
- **Why:** Eliminates the need for a separate SPA build pipeline, JSON serialization glue code, or client-side polling. The server pushes minimal binary diffs over a single persistent WebSocket. LiveView Streams append new items to the DOM without holding the entire event collection in BEAM process memory, preventing memory leaks during long-lived browser sessions.
- **Trade-off:** Requires persistent WebSocket connections and sticky routing or BEAM distributed clustering in multi-node setups.

### 4. Zero-Cost Cold Standby on Fly.io
- **Decision:** Production deployed with `auto_stop_machines = 'stop'`, `min_machines_running = 0`, and unmanaged single-node PostgreSQL connected over Fly's private IPv6 network (`ECTO_IPV6=true`).
- **Why:** Incurs $0 in compute when idle. Machines automatically wake in <500ms when an API request or dashboard viewer arrives.
- **Trade-off:** A cold-start delay on the initial incoming request after an idle period.

## Production Scaling Roadmap

To scale this pipeline from a single node to hundreds of thousands of events per second:

1. **Ingestion Buffering (Broadway / Kafka):**
   Decouple HTTP ingestion response times from database disk writes by buffering events in Broadway or Kafka partitions, writing to PostgreSQL in micro-batches (`Repo.insert_all`).
2. **Time-Series Partitioning:**
   Range-partition the `events` table by `timestamp` (monthly) to keep B-tree indexes compact and enable instantaneous historical data drops.
3. **Distributed Clustering (`libcluster`):**
   Enable `libcluster` over Fly.io's private WireGuard mesh (`6PN`) so `Phoenix.PubSub` broadcasts seamlessly across multi-region BEAM nodes.
4. **Read/Write Splitting:**
   Route customer dashboard reads to read-replicas while keeping write-heavy ingest API traffic isolated on the primary node.

## Production Deployment (Fly.io)

The project includes production-ready Docker packaging and Fly.io configurations. Verified in production (see dashboard screenshot above).

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

### Tearing Down (Zero-Cost Cleanup)

To completely remove all cloud resources, delete persistent disk volumes, and ensure zero charges:

```bash
# Destroy web application and database (releases VMs, IPs, and disk volumes)
fly apps destroy tallyho -y
fly apps destroy tallyho-db -y
```

**To relaunch later from scratch:**
```bash
fly launch --no-deploy
# When prompted for Postgres, select Unmanaged / Development Postgres (single node)
fly deploy
```

### Operations & Management Cheatsheet

```bash
# Fly.io Operations
fly status                           # View app status and machine states (stopped vs running)
fly status -a <app-name>-db          # View Postgres database machine state
fly logs                             # Stream live application logs
fly ssh console                      # Open remote IEx shell inside running production container
fly machine stop <machine-id>        # Halt a specific machine manually
fly scale count 0                    # Spin down all web machines to zero
fly apps destroy <app-name> -y       # Delete app and all associated persistent volumes

# Local Development & Quality
mix setup                            # Install dependencies, set up DB, build assets
mix phx.server                       # Start local server on localhost:4000
iex -S mix phx.server                # Start local server with interactive Elixir REPL
iex -S mix                           # Start REPL without web server (test modules/contexts directly)
mix test                             # Run test suite
mix test --trace                     # Run ExUnit tests with detailed trace
mix precommit                        # Full CI verification: compile warnings, format, tests
mix format                           # Format all .ex and .heex files

# Database Lifecycle (Ecto)
mix ecto.reset                       # Drop DB, recreate, migrate, and run seeds (clean slate)
mix ecto.migrate                     # Run any pending database migrations
mix ecto.rollback                    # Roll back the latest migration
```
