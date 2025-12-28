defmodule Multidb.MigrationRunner do
  @moduledoc """
  Manages database migrations for different adapters.
  Migrations are pre-compiled Elixir modules, not .exs script files.
  
  This approach avoids compilation warnings when migrations are run multiple times
  during tests or namespace creation.
  """

  @doc """
  Get migration list for given database driver.
  
  Returns a list of {version_number, module} tuples.
  """
  def migrations(:postgres) do
    [
      {1, Multidb.Migrations.Postgres.V001CreateUsers}
    ]
  end

  def migrations(:sqlite) do
    [
      {1, Multidb.Migrations.Sqlite.V001CreateUsers}
    ]
  end

  @doc """
  Run migrations for the default namespace.
  
  Options:
  - `:all` - run all pending migrations (default: true)
  - `:log` - log level for migrations (default: :info in dev/prod, false in test)
  - `:prefix` - schema/prefix to run migrations in (PostgreSQL only)
  """
  def run_for_default(db_driver, opts \\ []) do
    migs = migrations(db_driver)
    repo = default_repo(db_driver)
    
    run_opts = [
      all: Keyword.get(opts, :all, true),
      log: Keyword.get(opts, :log, migration_log_level()),
      prefix: Keyword.get(opts, :prefix, default_prefix(db_driver))
    ]

    Ecto.Migrator.run(repo, migs, :up, run_opts)
  end

  @doc """
  Run migrations for a specific namespace.
  
  For PostgreSQL: runs migrations in the specified schema (prefix)
  For SQLite: runs migrations on the namespace-specific repo
  
  Options:
  - `:all` - run all pending migrations (default: true)
  - `:log` - log level for migrations (default: false)
  """
  def run_for_namespace(db_driver, namespace_id, opts \\ [])

  def run_for_namespace(:postgres, namespace_id, opts) do
    migs = migrations(:postgres)
    
    run_opts = [
      all: Keyword.get(opts, :all, true),
      log: Keyword.get(opts, :log, false),
      prefix: namespace_prefix(:postgres, namespace_id)
    ]

    Ecto.Migrator.run(Multidb.PostgresRepo, migs, :up, run_opts)
  end

  def run_for_namespace(:sqlite, _namespace_id, opts) do
    # For SQLite, the caller should set the dynamic repo before calling this
    # This is handled in NamespaceRegistry.run_migrations/2
    migs = migrations(:sqlite)
    
    run_opts = [
      all: Keyword.get(opts, :all, true),
      log: Keyword.get(opts, :log, false),
      prefix: nil
    ]

    Ecto.Migrator.run(Multidb.SqliteRepo, migs, :up, run_opts)
  end

  # Private functions

  defp default_repo(:postgres), do: Multidb.PostgresRepo
  defp default_repo(:sqlite), do: Multidb.SqliteRepo

  defp default_prefix(:postgres), do: "public"
  defp default_prefix(:sqlite), do: nil

  defp namespace_prefix(:postgres, namespace_id), do: sanitize_namespace_id(namespace_id)

  defp sanitize_namespace_id(id) do
    # Ensure namespace IDs are safe for use as PostgreSQL schema names
    String.replace(id, ~r/[^a-zA-Z0-9_]/, "_")
  end

  defp migration_log_level do
    if Mix.env() == :test, do: false, else: :info
  end
end
