defmodule Multidb.Namespace do
  @moduledoc """
  Public API for namespace management.
  
  Namespaces provide data isolation for multi-tenant applications.
  
  ## Implementation
  
  - **PostgreSQL**: Uses native schemas (`CREATE SCHEMA`)
  - **SQLite**: Not yet implemented (planned: separate database files)
  
  ## Usage
  
      # Create a namespace
      Multidb.Namespace.create("tenant_acme")
      
      # Set namespace for current process
      Multidb.NamespaceContext.put("tenant_acme")
      
      # All database operations now use this namespace
      Multidb.Repo.insert(%User{name: "Alice", email: "alice@acme.com"})
      
      # List namespaces
      Multidb.Namespace.list()
      
      # Delete a namespace
      Multidb.Namespace.delete("tenant_acme")
  """
  
  alias Multidb.Repo
  
  @type namespace :: String.t()
  @type adapter :: :postgres | :sqlite
  
  @doc """
  Creates a new namespace.
  
  For PostgreSQL, this creates a new schema and runs migrations on it.
  For SQLite, this creates a separate database file and starts a repo instance.
  """
  @spec create(namespace()) :: :ok | {:error, term()}
  def create(namespace) when is_binary(namespace) do
    case get_adapter() do
      :postgres ->
        # In test mode, skip migrations (will be run separately)
        opts = if Mix.env() == :test, do: [skip_migrations: true], else: []
        Multidb.Adapters.PostgresNamespace.create(namespace, opts)
      
      :sqlite ->
        # Create the database file and start repo
        Multidb.Adapters.SqliteNamespace.create(namespace)
        # Ensure repo is started
        case Multidb.NamespaceRegistry.get_or_start_repo(namespace) do
          name when is_atom(name) -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @doc """
  Deletes a namespace and all its data.
  
  **Warning**: This is a destructive operation and cannot be undone!
  """
  @spec delete(namespace()) :: :ok | {:error, term()}
  def delete(namespace) when is_binary(namespace) do
    case get_adapter() do
      :postgres ->
        Multidb.Adapters.PostgresNamespace.delete(namespace)
      
      :sqlite ->
        # Stop the repo first
        Multidb.NamespaceRegistry.stop_repo(namespace)
        # Delete the database file
        Multidb.Adapters.SqliteNamespace.delete(namespace)
    end
  end
  
  @doc """
  Lists all namespaces.
  """
  @spec list() :: [namespace()]
  def list do
    case get_adapter() do
      :postgres ->
        Multidb.Adapters.PostgresNamespace.list()
      
      :sqlite ->
        Multidb.Adapters.SqliteNamespace.list()
    end
  end
  
  @doc """
  Checks if a namespace exists.
  """
  @spec exists?(namespace()) :: boolean()
  def exists?(namespace) when is_binary(namespace) do
    case get_adapter() do
      :postgres ->
        Multidb.Adapters.PostgresNamespace.exists?(namespace)
      
      :sqlite ->
        Multidb.Adapters.SqliteNamespace.exists?(namespace)
    end
  end
  
  @doc """
  Returns the current database adapter.
  """
  @spec get_adapter() :: adapter()
  def get_adapter do
    case Repo.active_repo() do
      Multidb.PostgresRepo -> :postgres
      Multidb.SqliteRepo -> :sqlite
    end
  end
end
