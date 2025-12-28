# Load support files
Code.require_file("support/data_case.ex", __DIR__)

ExUnit.start()

# Set up Ecto Sandbox for tests
repo = Multidb.Repo.active_repo()
db_adapter = System.get_env("DB_ADAPTER", "sqlite")
use_memory = System.get_env("SQLITE_IN_MEMORY", "false") == "true"

# Prepare database for tests
cond do
  db_adapter == "sqlite" && use_memory ->
    # For in-memory SQLite, create a permanent connection to keep schema alive
    IO.puts("Setting up in-memory SQLite database for tests...")
    _owner_pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, shared: true)
    
    # Run migrations on this connection
    migrations_path = Path.join([:code.priv_dir(:multidb), "repo", "migrations"])
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
    
  db_adapter == "sqlite" ->
    # For file-based SQLite, ensure database exists and run migrations
    IO.puts("Setting up file-based SQLite database for tests...")
    migrations_path = Path.join([:code.priv_dir(:multidb), "repo", "migrations"])
    
    # Run migrations (will create database if it doesn't exist)
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
    
  true ->
    # For PostgreSQL, migrations should already be run
    # (by mix multidb.migrate in the test script)
    IO.puts("Setting up PostgreSQL database for tests...")
    # Don't run migrations here - they're run outside the test process
end

# Use :manual mode for sandbox - allows test isolation
Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
