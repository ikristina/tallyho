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

Or inside IEx (interactive Elixir REPL):

```bash
iex -S mix phx.server
```

## Troubleshooting

**`role "postgres" does not exist`** — Homebrew creates a role matching your macOS username, not `postgres`. Fix with:

```bash
createuser -s postgres
```

## Learn more

- [Phoenix docs](https://phoenix.hexdocs.pm)
- [Phoenix guides](https://phoenix.hexdocs.pm/overview.html)
- [Elixir docs](https://hexdocs.pm/elixir)
