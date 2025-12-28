# Multidb - Runtime Database Adapter Switching

This project demonstrates how to support **multiple database adapters** (PostgreSQL and SQLite) in an Elixir/Ecto application with **runtime switching** - no recompilation needed!

## The Challenge

Traditional Ecto applications hardcode the Repo and adapter at compile time, making it impossible to switch databases at runtime. This project solves that problem.

## The Solution

### Architecture

1. **Two Separate Repo Modules**
   - `Multidb.PostgresRepo` - Uses `Ecto.Adapters.Postgres`
   - `Multidb.SqliteRepo` - Uses `Ecto.Adapters.SQLite3`

2. **Dynamic Repo Facade** (`Multidb.Repo`)
   - Provides a unified interface
   - Delegates to the active repo based on `DB_ADAPTER` environment variable
   - Checks environment variable on each call (true runtime switching)

3. **Conditional Supervision**
   - `Multidb.Application` starts only the selected repo
   - Determined by `DB_ADAPTER` at application startup

4. **Runtime Configuration** (`config/runtime.exs`)
   - Evaluated when application starts (not at compile time)
   - Configures the appropriate repo based on environment variables

### Key Design Decisions

**Why Two Repos?**
- Ecto adapters are configured at compile time in the `use Ecto.Repo` macro
- We need separate modules for different adapters
- The facade pattern allows us to choose between them at runtime

**Why Check ENV on Each Call?**
- Enables true runtime switching within the same VM
- No restart needed to change databases (though supervisor starts only one)
- Could be optimized with Application env if needed

**Trade-offs:**
- Small overhead from dynamic dispatch (negligible in practice)
- Both adapters compiled into the release (but only one runs)
- More maintainable than macros or code generation

## Usage

### Installation

```bash
mix deps.get
```

### Running with SQLite (Default)

```bash
# Run migrations
mix multidb.migrate

# Start IEx
iex -S mix

# Run demo
iex> Multidb.Demo.run()
iex> Multidb.Demo.info()
```

### Running with PostgreSQL

First, ensure PostgreSQL is running and create the database:

```bash
# Set environment variable for PostgreSQL
export DB_ADAPTER=postgres

# Optional: Configure connection (defaults shown)
export DB_NAME=multidb_dev
export DB_USER=postgres
export DB_PASSWORD=postgres
export DB_HOST=localhost
export DB_PORT=5432

# Run migrations
mix multidb.migrate

# Start IEx
iex -S mix

# Run demo
iex> Multidb.Demo.run()
iex> Multidb.Demo.info()
```

### Switching at Runtime (Same Command)

```bash
# SQLite
DB_ADAPTER=sqlite mix multidb.migrate
DB_ADAPTER=sqlite iex -S mix

# PostgreSQL
DB_ADAPTER=postgres mix multidb.migrate
DB_ADAPTER=postgres iex -S mix
```

### Reset Database

```bash
# SQLite
mix multidb.reset

# PostgreSQL
DB_ADAPTER=postgres mix multidb.reset
```

## Code Examples

### Using the Repo Directly

```elixir
# The Repo automatically delegates to the active adapter
alias Multidb.Repo
alias Multidb.User

# Insert
{:ok, user} = Repo.insert(%User{name: "Alice", email: "alice@example.com"})

# Query
users = Repo.all(User)
user = Repo.get(User, 1)

# Update
changeset = User.changeset(user, %{age: 30})
{:ok, updated} = Repo.update(changeset)

# Delete
{:ok, deleted} = Repo.delete(user)
```

### Using Context Modules

```elixir
alias Multidb.Accounts

# Create
{:ok, user} = Accounts.create_user(%{
  name: "Bob",
  email: "bob@example.com",
  age: 25
})

# List
users = Accounts.list_users()

# Get
user = Accounts.get_user!(1)

# Update
{:ok, updated} = Accounts.update_user(user, %{age: 26})

# Delete
{:ok, deleted} = Accounts.delete_user(user)

# Count
count = Accounts.count_users()
```

### Checking Active Adapter

```elixir
# Get the active repo module
Multidb.Repo.active_repo()
# => Multidb.SqliteRepo or Multidb.PostgresRepo

# Get demo info
Multidb.Demo.info()
# => %{
#   adapter: "SQLite",
#   repo_module: Multidb.SqliteRepo,
#   env_var: "sqlite"
# }
```

## File Structure

```
lib/
├── multidb/
│   ├── application.ex           # Starts the selected repo
│   ├── repo.ex                  # Dynamic facade that delegates
│   ├── repos/
│   │   ├── postgres_repo.ex     # PostgreSQL repo
│   │   └── sqlite_repo.ex       # SQLite repo
│   ├── schemas/
│   │   └── user.ex              # Example schema
│   ├── accounts.ex              # Example context
│   └── demo.ex                  # Demo module
├── mix/
│   └── tasks/
│       ├── multidb.migrate.ex   # Migration task
│       └── multidb.reset.ex     # Reset task
└── multidb.ex

config/
├── config.exs                   # Compile-time config
└── runtime.exs                  # Runtime config (reads ENV vars)

priv/
└── repo/
    └── migrations/
        └── 20231228000001_create_users.exs
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_ADAPTER` | `sqlite` | Database adapter: `sqlite` or `postgres` |
| `DB_PATH` | `multidb_dev.db` | SQLite database file path |
| `DB_NAME` | `multidb_dev` | PostgreSQL database name |
| `DB_USER` | `postgres` | PostgreSQL username |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `POOL_SIZE` | `10` (PG) / `5` (SQLite) | Connection pool size |

## How It Works

### 1. Application Startup

```elixir
# lib/multidb/application.ex
def start(_type, _args) do
  db_adapter = System.get_env("DB_ADAPTER", "sqlite")
  
  repo = case db_adapter do
    "postgres" -> Multidb.PostgresRepo
    "sqlite" -> Multidb.SqliteRepo
  end
  
  children = [repo]
  Supervisor.start_link(children, opts)
end
```

### 2. Runtime Configuration

```elixir
# config/runtime.exs
db_adapter = System.get_env("DB_ADAPTER", "sqlite")

case db_adapter do
  "postgres" ->
    config :multidb, Multidb.PostgresRepo, [...]
  "sqlite" ->
    config :multidb, Multidb.SqliteRepo, [...]
end
```

### 3. Dynamic Delegation

```elixir
# lib/multidb/repo.ex
def all(queryable, opts \\ []) do
  active_repo().all(queryable, opts)
end

def active_repo do
  case System.get_env("DB_ADAPTER", "sqlite") do
    "postgres" -> Multidb.PostgresRepo
    "sqlite" -> Multidb.SqliteRepo
  end
end
```

## Testing

### Quick Start

```bash
# Test with SQLite (recommended for local development)
./test_sqlite.sh

# Test with both SQLite AND PostgreSQL
./test_all_databases.sh
```

### Running Against Specific Databases

You can write tests that run against both databases:

```elixir
# test/multidb_test.exs
defmodule MultidbTest do
  use ExUnit.Case
  
  setup do
    # Clean database before each test
    Multidb.Repo.delete_all(Multidb.User)
    :ok
  end
  
  test "creates and retrieves users" do
    {:ok, user} = Multidb.Accounts.create_user(%{
      name: "Test User",
      email: "test@example.com"
    })
    
    assert user.id
    assert user.name == "Test User"
    
    retrieved = Multidb.Accounts.get_user!(user.id)
    assert retrieved.email == "test@example.com"
  end
end
```

Run tests with different adapters:

```bash
# SQLite (file-based, recommended)
MIX_ENV=test mix test

# SQLite (using helper script)
./test_sqlite.sh

# PostgreSQL (requires setup)
DB_ADAPTER=postgres MIX_ENV=test mix test

# Run against BOTH databases
./test_all_databases.sh
```

**Test Results:**

```
==========================================
Running Tests Against All Databases
==========================================

✓ SQLite (file-based) tests PASSED
✓ PostgreSQL tests PASSED

All tests passed! ✓
```

For more details on testing, see [TESTING.md](TESTING.md).

## Production Considerations

### Releases

For Mix releases, set the environment variable at runtime:

```bash
# Build release
MIX_ENV=prod mix release

# Run with SQLite
DB_ADAPTER=sqlite _build/prod/rel/multidb/bin/multidb start

# Run with PostgreSQL
DB_ADAPTER=postgres DB_HOST=prod-db.example.com _build/prod/rel/multidb/bin/multidb start
```

### Docker

```dockerfile
FROM elixir:1.18

ENV DB_ADAPTER=postgres
ENV DB_HOST=db
ENV DB_NAME=myapp_prod

WORKDIR /app
COPY . .

RUN mix deps.get
RUN MIX_ENV=prod mix compile

CMD ["mix", "multidb.migrate", "&&", "mix", "run", "--no-halt"]
```

### Performance

The dynamic dispatch overhead is negligible (sub-microsecond). If needed, you can optimize by:

1. Caching the active repo in Application environment
2. Using a compile-time flag for releases that only need one adapter
3. Using ETS for even faster lookups

## Limitations and Alternatives

### Limitations

1. **Single Active Repo**: Only one database can be active per VM instance
   - For multi-tenant with different DBs, use Ecto's `prefix` option instead
   
2. **Both Adapters in Release**: Both dependencies compiled in
   - Minimal overhead, but could use compile-time flags if needed

3. **Migration Handling**: Need to run migrations for each adapter separately
   - Could be improved with a task that handles both

### Alternative Approaches

1. **Multiple Repos Running Simultaneously**: If you need to query both databases in the same request, start both repos and use them directly (not through the facade)

2. **Dynamic Repo with Repository Pattern**: Use structs instead of modules to configure repos at runtime (more complex)

3. **Ecto Multi-tenancy with Prefixes**: If you need the same adapter but different databases

## License

MIT

## Contributing

Feel free to open issues or PRs!
