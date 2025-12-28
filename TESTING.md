# Testing Guide

This document explains how to run tests for the Multidb project against different database adapters.

## Quick Start

```bash
# Test with SQLite (file-based - RECOMMENDED)
./test_sqlite.sh

# Test with all available databases
./test_all_databases.sh
```

## Running Tests

### SQLite (File-Based - Default & Recommended)

File-based SQLite with Sandbox mode provides the best testing experience with proper isolation between tests.

```bash
# Default - uses file-based SQLite (multidb_test.db)
MIX_ENV=test mix test

# Or use the helper script
./test_sqlite.sh
```

**Advantages:**
- ✅ Proper test isolation via Ecto.Adapters.SQL.Sandbox
- ✅ Fast and reliable
- ✅ No external dependencies
- ✅ Database file is automatically created and cleaned

### SQLite (In-Memory)

⚠️ **WARNING:** In-memory SQLite has limitations with Ecto's Sandbox mode and connection pooling.

**The Issue:**
- Each connection from the pool sees a different in-memory database
- Schema created on one connection is not visible to others
- This breaks test isolation in Sandbox mode

**Current Status:**
In-memory mode is **not recommended** for testing due to these fundamental limitations. The file-based approach is just as fast for tests and much more reliable.

If you still want to try it (not guaranteed to work):

```bash
SQLITE_IN_MEMORY=true MIX_ENV=test mix test
```

### PostgreSQL

PostgreSQL tests require a running PostgreSQL instance.

```bash
# Ensure PostgreSQL is running
# Default connection: postgres@localhost:5432

# Set environment
export DB_ADAPTER=postgres
export DB_NAME=multidb_test

# Create test database
createdb -U postgres multidb_test

# Run migrations
MIX_ENV=test mix multidb.migrate

# Run tests
MIX_ENV=test mix test

# Cleanup
dropdb -U postgres multidb_test
```

**Or use the automated script:**

```bash
# This will handle database creation, migration, testing, and cleanup
DB_ADAPTER=postgres ./test_all_databases.sh
```

### Custom PostgreSQL Configuration

```bash
export DB_ADAPTER=postgres
export DB_NAME=myapp_test
export DB_USER=myuser
export DB_PASSWORD=mypassword  
export DB_HOST=localhost
export DB_PORT=5432

MIX_ENV=test mix test
```

## Running Against Both Databases

The `test_all_databases.sh` script runs the full test suite against both SQLite and PostgreSQL (if available):

```bash
./test_all_databases.sh
```

This script will:
1. Run all tests with SQLite (file-based, in-memory)
2. Check if PostgreSQL is available
3. If PostgreSQL is available:
   - Create a fresh test database
   - Run migrations
   - Run all tests
   - Clean up the test database
4. Report results for each adapter

## Test Database Cleanup

### SQLite

```bash
# Remove test database file
rm -f multidb_test.db*
```

### PostgreSQL

```bash
dropdb -U postgres --if-exists multidb_test
```

## Continuous Integration

For CI environments, we recommend:

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        db: [sqlite, postgres]
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18'
          otp-version: '27'
      
      - name: Install dependencies
        run: mix deps.get
      
      - name: Run tests (SQLite)
        if: matrix.db == 'sqlite'
        run: MIX_ENV=test mix test
      
      - name: Setup PostgreSQL database
        if: matrix.db == 'postgres'
        env:
          DB_ADAPTER: postgres
          DB_NAME: multidb_test
          DB_USER: postgres
          DB_PASSWORD: postgres
          DB_HOST: localhost
        run: |
          createdb -U postgres multidb_test
          MIX_ENV=test mix multidb.migrate
      
      - name: Run tests (PostgreSQL)
        if: matrix.db == 'postgres'
        env:
          DB_ADAPTER: postgres
          DB_NAME: multidb_test
          DB_USER: postgres
          DB_PASSWORD: postgres
          DB_HOST: localhost
        run: MIX_ENV=test mix test
```

## Test Configuration

Test configuration is defined in:

- `config/runtime.exs` - Database connection settings
- `test/test_helper.exs` - Test setup and migrations
- `test/support/data_case.ex` - Shared test setup

### Key Configuration Points

1. **Database Path (SQLite):**
   ```elixir
   # config/runtime.exs
   db_path = System.get_env("DB_PATH", "multidb_test.db")
   ```

2. **In-Memory Mode (SQLite):**
   ```elixir
   use_memory = System.get_env("SQLITE_IN_MEMORY", "false") == "true"
   ```

3. **Sandbox Mode:**
   All tests use Ecto.Adapters.SQL.Sandbox for transaction-based test isolation.

## Troubleshooting

### "no such table" errors

This usually means migrations haven't run. Ensure you run:

```bash
MIX_ENV=test mix multidb.migrate
```

Or migrations will run automatically when you start tests via `test/test_helper.exs`.

### Database locked errors (SQLite)

These are usually transient connection pool initialization errors and can be ignored. If persistent:

```bash
# Clean up and try again
rm -f multidb_test.db*
MIX_ENV=test mix test
```

### PostgreSQL connection errors

Ensure PostgreSQL is running and accessible:

```bash
# Test connection
psql -U postgres -c "SELECT 1"

# Check if test database exists
psql -U postgres -l | grep multidb_test
```

### Permission errors (PostgreSQL)

Ensure your PostgreSQL user has permission to create databases:

```bash
# Grant permissions
psql -U postgres -c "ALTER USER myuser CREATEDB;"
```

## Writing Tests

Tests should use `Multidb.DataCase` for database access:

```elixir
defmodule MyApp.MyTest do
  use Multidb.DataCase
  
  alias Multidb.Repo
  alias Multidb.User
  
  test "creates a user" do
    {:ok, user} = Repo.insert(%User{name: "Test", email: "test@example.com"})
    assert user.id
  end
end
```

The `DataCase` module:
- Sets up Sandbox mode for test isolation
- Handles cleanup after each test
- Provides helper functions like `errors_on/1`

## Performance

### SQLite (File-Based)
- ~50-100ms for full test suite
- No external dependencies
- Perfect for local development

### PostgreSQL
- ~100-200ms for full test suite
- Requires PostgreSQL server
- Better for production-like testing

Both are fast enough for TDD workflows!
