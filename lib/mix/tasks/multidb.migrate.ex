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
    
    repo = Multidb.Repo.active_repo()
    adapter = System.get_env("DB_ADAPTER", "sqlite")
    
    IO.puts("Running migrations for #{adapter} (#{inspect(repo)})...")
    
    # Start the repo
    {:ok, _} = Application.ensure_all_started(:multidb)
    
    # Run migrations
    migrations_path = Path.join([:code.priv_dir(:multidb), "repo", "migrations"])
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
    
    IO.puts("Migrations completed for #{adapter}")
  end
end
