defmodule Multidb.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Determine which repo to start based on environment variable
    db_adapter = System.get_env("DB_ADAPTER", "sqlite")
    
    repo = case db_adapter do
      "postgres" -> Multidb.PostgresRepo
      "sqlite" -> Multidb.SqliteRepo
      other ->
        raise """
        Invalid DB_ADAPTER: #{other}
        Valid values are: postgres, sqlite
        """
    end

    IO.puts("Starting Multidb with #{db_adapter} adapter (#{inspect(repo)})")

    children = [
      # Start the selected repo
      repo
    ]

    opts = [strategy: :one_for_one, name: Multidb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
