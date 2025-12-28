defmodule Multidb.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize and store the active repo in :persistent_term for fast access
    repo = Multidb.Repo.init()
    
    db_adapter = System.get_env("DB_ADAPTER", "sqlite")
    IO.puts("Starting Multidb with #{db_adapter} adapter (#{inspect(repo)})")

    children = [
      # Start the selected repo
      repo
    ]

    opts = [strategy: :one_for_one, name: Multidb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
