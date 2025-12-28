# Project Structure

Streamlined proof of concept for runtime database switching in Elixir/Ecto.

## Core Files (20 total)

### Application Code (14 files)
```
lib/
├── multidb/
│   ├── repos/
│   │   ├── postgres_repo.ex      # PostgreSQL adapter
│   │   └── sqlite_repo.ex        # SQLite adapter
│   ├── schemas/
│   │   └── user.ex               # Example schema
│   ├── accounts.ex               # Example context
│   ├── application.ex            # Starts active repo
│   ├── demo.ex                   # Demo script
│   └── repo.ex                   # Facade pattern (KEY!)
└── mix/tasks/
    ├── multidb.migrate.ex        # Migration task
    └── multidb.reset.ex          # Reset database task
```

### Configuration (3 files)
```
config/
├── config.exs                    # Compile-time config
├── runtime.exs                   # Runtime config (KEY!)
└── test.exs                      # Test environment
```

### Tests (3 files)
```
test/
├── support/
│   └── data_case.ex              # Test helpers
├── multidb_test.exs              # Main tests
└── test_helper.exs               # Test setup
```

## Key Concepts

1. **Two Repos** - One for each adapter
2. **Facade Pattern** - `Multidb.Repo` delegates to active repo
3. **Runtime Config** - `config/runtime.exs` reads `DB_ADAPTER` env var
4. **Conditional Supervision** - Only starts the active repo

## Usage

```bash
# SQLite
mix multidb.reset
iex -S mix

# PostgreSQL
DB_ADAPTER=postgres mix multidb.reset
DB_ADAPTER=postgres iex -S mix

# Run demo
iex> Multidb.Demo.run()

# Test both
./test_all_databases.sh
```

## What Was Removed

- 6 redundant documentation files (kept only README.md)
- 4 redundant scripts (kept only test_all_databases.sh)
- lib/multidb.ex (unused hello world)
- @meta/ directory (wiki metadata)
- .lexical/ directory (IDE cache)

Total reduction: ~2,300 lines of redundant documentation

## Test Status

✅ All 11 tests passing on both SQLite and PostgreSQL
✅ Clean output with minimal logging
✅ Demo runs successfully
