defmodule Mix.Tasks.Multidb.Reset do
  @moduledoc """
  Drops and recreates the database, then runs migrations.

  ## Examples

      # Reset SQLite (default)
      $ mix multidb.reset

      # Reset PostgreSQL
      $ DB_ADAPTER=postgres mix multidb.reset
  """
  use Mix.Task

  @shortdoc "Drops, creates, and migrates the database"

  @impl Mix.Task
  def run(_args) do
    adapter = System.get_env("DB_ADAPTER", "sqlite")

    case adapter do
      "sqlite" ->
        # For SQLite, just delete the database file
        db_path = System.get_env("DB_PATH", "data/multidb_dev.db")

        if File.exists?(db_path) do
          File.rm!(db_path)
          IO.puts("Deleted SQLite database: #{db_path}")
        end

      "postgres" ->
        # For PostgreSQL, drop and create the database
        Mix.Task.run("app.config")
        repo = Multidb.PostgresRepo

        # Drop the database
        case repo.__adapter__().storage_down(repo.config()) do
          :ok -> IO.puts("Database dropped")
          {:error, :already_down} -> IO.puts("Database already down")
          {:error, term} -> Mix.raise("The database could not be dropped: #{inspect(term)}")
        end

        # Create the database
        case repo.__adapter__().storage_up(repo.config()) do
          :ok -> IO.puts("Database created")
          {:error, :already_up} -> IO.puts("Database already exists")
          {:error, term} -> Mix.raise("The database could not be created: #{inspect(term)}")
        end
    end

    # Run migrations
    Mix.Task.run("multidb.migrate", [])
  end
end
