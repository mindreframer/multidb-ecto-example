# Quickstart Guide

This guide will get you up and running with Multidb in 5 minutes.

## Prerequisites

- Elixir 1.18+ installed
- PostgreSQL (optional, for PostgreSQL testing)

## Setup

```bash
# 1. Install dependencies
mix deps.get

# 2. Compile the project
mix compile
```

## Run with SQLite (Default)

```bash
# Create and migrate database
mix multidb.reset

# Start interactive shell
iex -S mix

# Run the demo
iex> Multidb.Demo.run()
```

**Output:**
```
============================================================
Multidb Demo - Using SQLite (Multidb.SqliteRepo)
============================================================

Creating users...
  ✓ Created: Alice Johnson (ID: 1)
  ✓ Created: Bob Smith (ID: 2)
  ✓ Created: Carol White (ID: 3)

Listing all users...
  - Alice Johnson (alice@example.com) - Age: 28
  - Bob Smith (bob@example.com) - Age: 35
  - Carol White (carol@example.com) - Age: 42

Total users: 3
...
Demo completed successfully with SQLite!
```

## Run with PostgreSQL

```bash
# Create PostgreSQL database
createdb -U postgres multidb_dev

# Set environment and migrate
DB_ADAPTER=postgres mix multidb.reset

# Start interactive shell
DB_ADAPTER=postgres iex -S mix

# Run the demo
iex> Multidb.Demo.run()
```

**Output:**
```
============================================================
Multidb Demo - Using PostgreSQL (Multidb.PostgresRepo)
============================================================

Creating users...
  ✓ Created: Alice Johnson (ID: 1)
  ...
Demo completed successfully with PostgreSQL!
```

## Run Tests

```bash
# Test with SQLite
./test_sqlite.sh

# Test with BOTH databases
./test_all_databases.sh
```

## Use in Your Code

```elixir
# The adapter is chosen at runtime - your code doesn't change!

alias Multidb.Repo
alias Multidb.User

# Create
{:ok, user} = Repo.insert(%User{
  name: "Alice",
  email: "alice@example.com",
  age: 28
})

# Read
users = Repo.all(User)
user = Repo.get(User, 1)

# Update
changeset = User.changeset(user, %{age: 29})
{:ok, updated} = Repo.update(changeset)

# Delete
{:ok, deleted} = Repo.delete(user)
```

## Check Which Database Is Active

```elixir
iex> Multidb.Demo.info()
%{
  adapter: "SQLite",
  repo_module: Multidb.SqliteRepo,
  env_var: "sqlite"
}

# Or check directly
iex> Multidb.Repo.active_repo()
Multidb.SqliteRepo
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_ADAPTER` | `sqlite` | `sqlite` or `postgres` |
| `DB_PATH` | `multidb_dev.db` | SQLite file path |
| `DB_NAME` | `multidb_dev` | PostgreSQL database |
| `DB_USER` | `postgres` | PostgreSQL user |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |

## Examples

### Use SQLite with Custom Path

```bash
DB_ADAPTER=sqlite DB_PATH=/tmp/myapp.db mix multidb.migrate
DB_ADAPTER=sqlite DB_PATH=/tmp/myapp.db iex -S mix
```

### Use PostgreSQL with Custom Settings

```bash
DB_ADAPTER=postgres \
DB_NAME=myapp_prod \
DB_USER=myuser \
DB_PASSWORD=secret \
DB_HOST=db.example.com \
mix multidb.migrate
```

### Production Release

```bash
# Build
MIX_ENV=prod mix release

# Run with SQLite
DB_ADAPTER=sqlite _build/prod/rel/multidb/bin/multidb start

# Run with PostgreSQL
DB_ADAPTER=postgres \
DB_HOST=prod-db.example.com \
DB_NAME=myapp_prod \
_build/prod/rel/multidb/bin/multidb start
```

## Next Steps

- Read [README_MULTIDB.md](README_MULTIDB.md) for complete documentation
- Read [TESTING.md](TESTING.md) for testing details
- Read [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) for architecture deep dive
- Check out the code in `lib/multidb/` to see how it works

## Troubleshooting

### "no such table: users"

Run migrations:
```bash
mix multidb.migrate
# or
mix multidb.reset
```

### PostgreSQL connection refused

Ensure PostgreSQL is running:
```bash
# Check status
pg_ctl status

# Start PostgreSQL (macOS with Homebrew)
brew services start postgresql

# Start PostgreSQL (Ubuntu)
sudo service postgresql start
```

### Database locked (SQLite)

These are usually transient errors. If persistent:
```bash
rm -f multidb_dev.db*
mix multidb.reset
```

## What's Happening Under the Hood?

1. **Environment Variable Read**: `DB_ADAPTER` env var is read at application startup
2. **Repo Selection**: Application supervisor starts the appropriate repo (SQLite or PostgreSQL)
3. **Facade Delegation**: `Multidb.Repo` delegates all calls to the active repo
4. **Transparent Usage**: Your application code works identically with both adapters

```
Your Code
    ↓
Multidb.Repo (facade)
    ↓
Multidb.Repo.active_repo() → checks ENV
    ↓
Either: Multidb.SqliteRepo OR Multidb.PostgresRepo
    ↓
Actual Database
```

## Key Insight

The magic is in `config/runtime.exs`:

```elixir
# This file is evaluated when the application STARTS (not when it compiles)
# So environment variables can control configuration without recompilation

db_adapter = System.get_env("DB_ADAPTER", "sqlite")

case db_adapter do
  "postgres" -> config :multidb, Multidb.PostgresRepo, [...]
  "sqlite" -> config :multidb, Multidb.SqliteRepo, [...]
end
```

This is why you can switch databases with just an environment variable!

## Ready to Build?

You now have a working Elixir application that can switch between SQLite and PostgreSQL at runtime. Start building your features - they'll work with both databases!

Happy coding! 🚀
