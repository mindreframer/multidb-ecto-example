import Config

# Reduce log noise during tests
config :logger, level: :warning

# We'll configure test databases in runtime.exs based on DB_ADAPTER
