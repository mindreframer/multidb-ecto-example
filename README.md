# Multidb - Runtime Database Switching for Ecto

Switch between PostgreSQL and SQLite at runtime via environment variable - no recompilation needed.

## Quick Start

```bash
# Install dependencies
mix deps.get

# Run with SQLite (default)
mix multidb.reset
iex -S mix

# Run with PostgreSQL  
DB_ADAPTER=postgres mix multidb.reset
DB_ADAPTER=postgres iex -S mix
```

## Demo

```elixir
iex> Multidb.Demo.run()
```

## The Problem

Traditional Ecto apps hardcode the database adapter at compile time:

```elixir
# config/config.exs
config :myapp, MyApp.Repo,
  adapter: Ecto.Adapters.Postgres  # HARDCODED - requires recompile to change
```

## The Solution

**Runtime configuration + facade pattern:**

1. **Two separate Repo modules** - one per adapter
2. **Dynamic facade** (`Multidb.Repo`) - delegates based on `DB_ADAPTER` env var  
3. **Runtime config** (`config/runtime.exs`) - evaluated at startup, not compile time
4. **Conditional supervision** - starts only the active repo

```elixir
# Switch databases with environment variable
DB_ADAPTER=sqlite iex -S mix      # Uses SQLite
DB_ADAPTER=postgres iex -S mix    # Uses PostgreSQL
```

## Usage

```elixir
alias Multidb.Repo
alias Multidb.Schemas.User

# Works with BOTH adapters - code doesn't change!
{:ok, user} = Repo.insert(%User{name: "Alice", email: "alice@example.com"})
users = Repo.all(User)
{:ok, updated} = Repo.update(User.changeset(user, %{age: 29}))
{:ok, deleted} = Repo.delete(user)

# Check which adapter is active
Repo.active_repo()  #=> Multidb.SqliteRepo or Multidb.PostgresRepo
```

## Testing

Run tests against both databases:

```bash
./test_all_databases.sh
```

## Architecture

```
lib/multidb/
├── repos/
│   ├── sqlite_repo.ex        # SQLite adapter
│   └── postgres_repo.ex      # PostgreSQL adapter
├── repo.ex                   # Facade that delegates to active repo
├── application.ex            # Starts correct repo based on DB_ADAPTER
├── schemas/user.ex           # Example schema
├── accounts.ex               # Example context
└── demo.ex                   # Demo module

config/
├── config.exs                # Compile-time config
└── runtime.exs               # Runtime config (KEY!)

lib/mix/tasks/
├── multidb.migrate.ex        # Run migrations
└── multidb.reset.ex          # Drop, create, migrate
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_ADAPTER` | `sqlite` | `sqlite` or `postgres` |
| `DB_PATH` | `multidb_dev.db` | SQLite file path |
| `DB_NAME` | `multidb_dev` | PostgreSQL database |
| `DB_USER` | `postgres` | PostgreSQL user |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `DB_HOST` | `localhost` | PostgreSQL host |

## How It Works

### Runtime Configuration

```elixir
# config/runtime.exs - evaluated at RUNTIME, not compile time
db_adapter = System.get_env("DB_ADAPTER", "sqlite")

case db_adapter do
  "postgres" ->
    config :multidb, Multidb.PostgresRepo,
      database: System.get_env("DB_NAME", "multidb_dev"),
      # ...
      
  "sqlite" ->
    config :multidb, Multidb.SqliteRepo,
      database: System.get_env("DB_PATH", "multidb_dev.db"),
      # ...
end
```

### Facade Pattern

```elixir
defmodule Multidb.Repo do
  def active_repo do
    case System.get_env("DB_ADAPTER", "sqlite") do
      "postgres" -> Multidb.PostgresRepo
      "sqlite" -> Multidb.SqliteRepo
    end
  end

  def all(queryable, opts \\ []) do
    active_repo().all(queryable, opts)
  end
  
  # ... delegate all other Ecto.Repo functions
end
```

### Conditional Supervision

```elixir
defmodule Multidb.Application do
  def start(_type, _args) do
    repo = case System.get_env("DB_ADAPTER", "sqlite") do
      "postgres" -> Multidb.PostgresRepo
      "sqlite" -> Multidb.SqliteRepo
    end

    children = [repo]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Why This Approach?

**Advantages:**
- True runtime switching without recompilation
- Simple and explicit code
- Full test coverage against both databases
- Minimal overhead (~100ns per delegation)

**Trade-offs:**
- Both adapters compiled into release (+~5MB)
- Only one database active per instance
- Small delegation overhead

**Perfect for:**
- Dev (SQLite) vs Production (PostgreSQL)
- Testing against multiple databases
- Edge deployments with varying infrastructure
- Desktop apps with optional cloud sync

## Production Deployment

```bash
# Mix Release
MIX_ENV=prod mix release
DB_ADAPTER=postgres DB_HOST=prod-db _build/prod/rel/multidb/bin/multidb start

# Docker
docker build -t multidb .
docker run -e DB_ADAPTER=postgres -e DB_HOST=db.example.com multidb
```

## License

MIT
