defmodule Multidb.NamespaceRegistry do
  use GenServer
  require Logger
  
  @moduledoc """
  Manages namespace-specific database connections for SQLite.
  
  Each namespace gets its own database file and repo instance.
  Repos are started on-demand and cached.
  """
  
  alias Multidb.Adapters.SqliteNamespace
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Gets or starts a repo for the given namespace.
  Returns the base SqliteRepo if namespace is nil.
  """
  def get_or_start_repo(nil), do: Multidb.SqliteRepo
  def get_or_start_repo(namespace) when is_binary(namespace) do
    GenServer.call(__MODULE__, {:get_or_start_repo, namespace}, 10_000)
  end
  
  @doc """
  Lists all active namespace repos.
  """
  def list_active_namespaces do
    GenServer.call(__MODULE__, :list_namespaces)
  end
  
  @doc """
  Stops a namespace repo if it's running.
  """
  def stop_repo(namespace) when is_binary(namespace) do
    GenServer.call(__MODULE__, {:stop_repo, namespace})
  end
  
  ## Server Callbacks
  
  @impl true
  def init(_) do
    # State: %{namespace => pid}
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:get_or_start_repo, namespace}, _from, state) do
    repo_name = get_repo_name(namespace)
    
    case Map.get(state, namespace) do
      nil ->
        # Start a new repo for this namespace
        case start_namespace_repo(namespace) do
          {:ok, _pid} ->
            new_state = Map.put(state, namespace, repo_name)
            {:reply, repo_name, new_state}
          
          {:error, {:already_started, _pid}} ->
            # Race condition - another process started it
            new_state = Map.put(state, namespace, repo_name)
            {:reply, repo_name, new_state}
            
          {:error, reason} ->
            Logger.error("Failed to start repo for namespace #{namespace}: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
        
      _repo_name ->
        {:reply, repo_name, state}
    end
  end
  
  @impl true
  def handle_call(:list_namespaces, _from, state) do
    {:reply, Map.keys(state), state}
  end
  
  @impl true
  def handle_call({:stop_repo, namespace}, _from, state) do
    case Map.get(state, namespace) do
      nil ->
        {:reply, :ok, state}
      
      repo_name when is_atom(repo_name) ->
        # Find the PID from the registered name
        case Process.whereis(repo_name) do
          nil ->
            # Already stopped
            new_state = Map.delete(state, namespace)
            {:reply, :ok, new_state}
          
          pid when is_pid(pid) ->
            # Stop the supervisor child using the PID
            DynamicSupervisor.terminate_child(Multidb.NamespaceSupervisor, pid)
            new_state = Map.delete(state, namespace)
            {:reply, :ok, new_state}
        end
    end
  end
  
  ## Private Functions
  
  defp get_repo_name(namespace) do
    # Create a unique atom for this repo instance
    String.to_atom("Elixir.Multidb.SqliteNamespaceRepo.#{namespace}")
  end
  
  defp start_namespace_repo(namespace) do
    # Ensure the database file exists
    SqliteNamespace.create(namespace)
    
    db_path = SqliteNamespace.get_db_path(namespace)
    repo_name = get_repo_name(namespace)
    
    # Start SqliteRepo with a specific name and database path
    # Use a regular connection pool (not Sandbox) for namespace repos
    opts = [
      name: repo_name,
      database: db_path,
      pool: DBConnection.ConnectionPool,
      pool_size: 2,
      after_connect: {Multidb.SqlitePragmas, :set_pragmas, []}
    ]
    
    child_spec = {Multidb.SqliteRepo, opts}
    
    case DynamicSupervisor.start_child(Multidb.NamespaceSupervisor, child_spec) do
      {:ok, _pid} = result ->
        # Run migrations on the new database
        run_migrations(repo_name, db_path)
        result
      
      error ->
        error
    end
  end
  
  defp run_migrations(repo_name, _db_path) do
    migrations_path = Path.join([:code.priv_dir(:multidb), "repo", "migrations"])
    
    try do
      # Set the dynamic repo to the namespace instance before running migrations
      Multidb.SqliteRepo.put_dynamic_repo(repo_name)
      
      # Run migrations on the namespace database
      # Use log: false to reduce noise
      Ecto.Migrator.run(Multidb.SqliteRepo, migrations_path, :up, all: true, log: false)
    rescue
      error ->
        # Ignore errors - migrations may already be run or DB locked temporarily
        Logger.debug("Migration info for namespace repo: #{inspect(error)}")
        :ok
    after
      # Reset to default
      Multidb.SqliteRepo.put_dynamic_repo(Multidb.SqliteRepo)
    end
  end
end
