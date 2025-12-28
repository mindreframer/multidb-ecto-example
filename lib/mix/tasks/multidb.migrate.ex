defmodule Mix.Tasks.Multidb.Migrate do
  @moduledoc """
  Runs migrations for the configured database adapter.
  
  ## Examples
  
      # Migrate SQLite (default)
      $ mix multidb.migrate
      
      # Migrate PostgreSQL
      $ DB_ADAPTER=postgres mix multidb.migrate
  """
  use Mix.Task

  @shortdoc "Runs migrations for the active database adapter"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")
    
    adapter = System.get_env("DB_ADAPTER", "sqlite")
    db_driver = String.to_atom(adapter)
    
    IO.puts("Running migrations for #{adapter}...")
    
    # Start the repo
    {:ok, _} = Application.ensure_all_started(:multidb)
    
    # Run migrations using precompiled modules
    Multidb.MigrationRunner.run_for_default(db_driver, log: :info)
    
    IO.puts("Migrations completed for #{adapter}")
  end
end
