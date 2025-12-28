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
# Basic demo - works with both SQLite and PostgreSQL
iex> Multidb.Demo.run()

# Namespace isolation demo - PostgreSQL only
iex> Multidb.NamespaceDemo.run()
```

## The Problem

Traditional Ecto apps hardcode the database adapter at compile time:

```elixir
# config/config.exs
config :myapp, MyApp.Repo,
  adapter: Ecto.Adapters.Postgres  # HARDCODED - requires recompile to change
```

## The Solution

**Runtime configuration + facade pattern + persistent term optimization:**

1. **Two separate Repo modules** - one per adapter
2. **Dynamic facade** (`Multidb.Repo`) - delegates based on `DB_ADAPTER` env var  
3. **Runtime config** (`config/runtime.exs`) - evaluated at startup, not compile time
4. **Conditional supervision** - starts only the active repo
5. **`:persistent_term` caching** - adapter choice stored once at boot for zero-overhead lookups

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

## Namespace Isolation (Multi-Tenancy)

**Transparent namespace support for complete data isolation** (works with both PostgreSQL and SQLite):

```elixir
alias Multidb.{Namespace, NamespaceContext, Repo, User}

# Create namespaces (PostgreSQL schemas)
Namespace.create("tenant_acme")
Namespace.create("tenant_globex")

# Set namespace for current process
NamespaceContext.put("tenant_acme")

# All operations automatically use this namespace - no explicit passing needed!
{:ok, user} = Repo.insert(%User{name: "Alice", email: "alice@acme.com"})
users = Repo.all(User)  # Only sees ACME data

# Switch to different namespace
NamespaceContext.put("tenant_globex")
users = Repo.all(User)  # Now sees Globex data - complete isolation!

# Temporary namespace switch
NamespaceContext.with_namespace("tenant_xyz", fn ->
  # Operations here use tenant_xyz
  Repo.insert(%User{name: "Bob", email: "bob@xyz.com"})
end)
# Previous namespace automatically restored

# List all namespaces
Namespace.list()

# Delete namespace (destructive!)
Namespace.delete("tenant_acme")
```

**Key features:**
- ✅ **Transparent** - No need to pass namespace to every function
- ✅ **Process-scoped** - Each request/process has its own namespace context
- ✅ **Type-safe** - Impossible to accidentally mix namespaces
- ✅ **Web-friendly** - Perfect for Phoenix plugs (see ADR001)
- ✅ **Zero API pollution** - Business logic stays clean

**Implementation:**
- **PostgreSQL**: Native schemas (`CREATE SCHEMA`) - single connection pool
- **SQLite**: Separate database files per namespace - dynamic repo instances

## Testing

Run tests against both databases:

```bash
./test_all_databases.sh
```

## Architecture

```
lib/multidb/
├── repos/
│   ├── sqlite_repo.ex            # SQLite adapter
│   ├── postgres_repo.ex          # PostgreSQL adapter
│   └── sqlite_namespace_repo.ex  # SQLite namespace wrapper (future)
├── repo.ex                       # Facade that delegates to active repo
├── namespace.ex                  # Public API for namespace management
├── namespace_context.ex          # Process-scoped namespace storage
├── namespace_registry.ex         # Namespace repo registry (for SQLite)
├── adapters/
│   ├── postgres_namespace.ex     # PostgreSQL schema operations
│   └── sqlite_namespace.ex       # SQLite namespace operations (future)
├── application.ex                # Starts correct repo based on DB_ADAPTER
├── schemas/user.ex               # Example schema
├── accounts.ex                   # Example context
├── demo.ex                       # Basic demo
└── namespace_demo.ex             # Namespace isolation demo

config/
├── config.exs                    # Compile-time config
└── runtime.exs                   # Runtime config (KEY!)

lib/mix/tasks/
├── multidb.migrate.ex            # Run migrations
└── multidb.reset.ex              # Drop, create, migrate

@meta/@adr/
└── ADR001-support-namespaces.md  # Architecture decision record
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

### Facade Pattern with Persistent Term

```elixir
defmodule Multidb.Repo do
  @persistent_term_key {__MODULE__, :active_repo}

  # Called once at application boot
  def init do
    repo = case System.get_env("DB_ADAPTER", "sqlite") do
      "postgres" -> Multidb.PostgresRepo
      "sqlite" -> Multidb.SqliteRepo
    end
    
    :persistent_term.put(@persistent_term_key, repo)
    repo
  end

  # Fast, lock-free lookup from :persistent_term
  def active_repo do
    case :persistent_term.get(@persistent_term_key, nil) do
      nil -> init()  # Fallback for Mix tasks
      repo -> repo
    end
  end

  def all(queryable, opts \\ []) do
    active_repo().all(queryable, opts)
  end
  
  # ... delegate all other Ecto.Repo functions
end
```

### Conditional Supervision with Initialization

```elixir
defmodule Multidb.Application do
  def start(_type, _args) do
    # Initialize and cache the active repo in :persistent_term
    repo = Multidb.Repo.init()

    children = [repo]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Performance

The facade pattern uses **`:persistent_term`** for near-zero overhead:

- **Adapter selection**: Read once from env var at boot, cached in `:persistent_term`
- **Per-query cost**: Single lock-free lookup (faster than reading env vars)
- **Memory**: Minimal (~1 atom stored)
- **GC impact**: None (`:persistent_term` data isn't copied during reads)

This is significantly faster than checking `System.get_env/2` on every query.

## Why This Approach?

**Advantages:**
- True runtime switching without recompilation
- Simple and explicit code
- Full test coverage against both databases
- Zero-overhead lookups via `:persistent_term` (lock-free, constant-time reads)
- Adapter choice determined once at boot, not on every query

**Trade-offs:**
- Both adapters compiled into release (+~5MB)
- Only one database active per instance
- Tiny delegation overhead (function call only)

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
