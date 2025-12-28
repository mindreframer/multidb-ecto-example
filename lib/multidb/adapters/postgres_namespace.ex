defmodule Multidb.Adapters.PostgresNamespace do
  @moduledoc """
  PostgreSQL-specific namespace operations using native schemas.
  
  Each namespace is a PostgreSQL schema (CREATE SCHEMA).
  """
  
  alias Multidb.PostgresRepo
  
  @doc """
  Creates a new PostgreSQL schema for the namespace.
  
  Options:
  - `:skip_migrations` - if true, don't run migrations (useful in tests)
  """
  def create(namespace, opts \\ []) when is_binary(namespace) do
    query = "CREATE SCHEMA IF NOT EXISTS #{quote_identifier(namespace)}"
    
    case PostgresRepo.query(query) do
      {:ok, _} -> 
        # Run migrations on the new schema unless explicitly skipped
        unless Keyword.get(opts, :skip_migrations, false) do
          run_migrations(namespace)
        end
        :ok
      {:error, reason} -> 
        {:error, reason}
    end
  end
  
  @doc """
  Deletes a PostgreSQL schema and all its data.
  """
  def delete(namespace) when is_binary(namespace) do
    query = "DROP SCHEMA IF EXISTS #{quote_identifier(namespace)} CASCADE"
    
    case PostgresRepo.query(query) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Lists all custom PostgreSQL schemas (excludes system schemas).
  """
  def list do
    query = """
    SELECT schema_name 
    FROM information_schema.schemata 
    WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'public', 'pg_toast')
    AND schema_name NOT LIKE 'pg_%'
    ORDER BY schema_name
    """
    
    case PostgresRepo.query(query) do
      {:ok, %{rows: rows}} -> 
        Enum.map(rows, fn [name] -> name end)
      {:error, _} -> 
        []
    end
  end
  
  @doc """
  Checks if a namespace (schema) exists.
  """
  def exists?(namespace) when is_binary(namespace) do
    namespace in list()
  end
  
  @doc """
  Runs migrations on a specific schema.
  """
  def run_migrations(namespace) when is_binary(namespace) do
    # Run migrations with prefix option using precompiled modules
    Multidb.MigrationRunner.run_for_namespace(:postgres, namespace, log: false)
  end
  
  # Quote identifier to prevent SQL injection
  defp quote_identifier(name) do
    # Simple validation: only allow alphanumeric and underscores
    unless name =~ ~r/^[a-zA-Z0-9_]+$/ do
      raise ArgumentError, "Invalid namespace name: #{name}. Only alphanumeric characters and underscores allowed."
    end
    
    ~s("#{name}")
  end
end
