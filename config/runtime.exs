import Config

# Runtime configuration - evaluated when the application starts
# This allows us to use environment variables

db_adapter = System.get_env("DB_ADAPTER", "sqlite")
env = config_env()

case db_adapter do
  "postgres" ->
    db_name =
      case env do
        :test -> System.get_env("DB_NAME", "multidb_test")
        _ -> System.get_env("DB_NAME", "multidb_dev")
      end

    config :multidb, Multidb.PostgresRepo,
      database: db_name,
      username: System.get_env("DB_USER", "postgres"),
      password: System.get_env("DB_PASSWORD", "postgres"),
      hostname: System.get_env("DB_HOST", "localhost"),
      port: String.to_integer(System.get_env("DB_PORT", "5432")),
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  "sqlite" ->
    db_path =
      case env do
        :test ->
          # For tests, optionally use in-memory or file-based
          # In-memory: "file:test_#{:erlang.unique_integer()}?mode=memory&cache=shared"
          # File-based (recommended for stability): "multidb_test.db"
          use_memory = System.get_env("SQLITE_IN_MEMORY", "false") == "true"

          if use_memory do
            # Named in-memory database with shared cache
            "file:test_mem?mode=memory&cache=shared&_journal_mode=WAL"
          else
            System.get_env("DB_PATH", "data/multidb_test.db")
          end

        _ ->
          System.get_env("DB_PATH", "data/multidb_#{env}.db")
      end

    pool =
      case env do
        :test -> Ecto.Adapters.SQL.Sandbox
        _ -> DBConnection.ConnectionPool
      end

    config :multidb, Multidb.SqliteRepo,
      database: db_path,
      pool: pool,
      pool_size: if(env == :test, do: 10, else: 5)

  other ->
    raise "Invalid DB_ADAPTER: #{other}. Valid values are: postgres, sqlite"
end
