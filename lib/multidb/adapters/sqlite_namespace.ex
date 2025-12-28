defmodule Multidb.Adapters.SqliteNamespace do
  @moduledoc """
  SQLite-specific namespace operations using separate database files.
  
  Each namespace gets its own database file: namespace_<name>_<env>.db
  """
  
  @doc """
  Creates a new SQLite database file for the namespace.
  Sets up WAL mode immediately to avoid locking issues.
  """
  def create(namespace) when is_binary(namespace) do
    db_path = get_db_path(namespace)
    
    # Create directory if needed
    File.mkdir_p!(Path.dirname(db_path))
    
    # Create and initialize the database with WAL mode
    unless File.exists?(db_path) do
      # Create database and set pragmas directly
      {:ok, conn} = Exqlite.Sqlite3.open(db_path)
      
      # Enable WAL mode immediately
      Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
      Exqlite.Sqlite3.execute(conn, "PRAGMA busy_timeout=10000")
      Exqlite.Sqlite3.execute(conn, "PRAGMA synchronous=NORMAL")
      
      # Close the connection
      Exqlite.Sqlite3.close(conn)
    end
    
    :ok
  end
  
  @doc """
  Deletes the SQLite database file for the namespace.
  """
  def delete(namespace) when is_binary(namespace) do
    db_path = get_db_path(namespace)
    
    if File.exists?(db_path) do
      File.rm(db_path)
    end
    
    # Also delete WAL and SHM files if they exist
    Enum.each(["-wal", "-shm", "-journal"], fn suffix ->
      wal_file = db_path <> suffix
      if File.exists?(wal_file), do: File.rm(wal_file)
    end)
    
    :ok
  end
  
  @doc """
  Lists all namespace database files.
  """
  def list do
    data_dir = get_data_dir()
    env = get_env()
    
    pattern = Path.join(data_dir, "namespace_*_#{env}.db")
    
    Path.wildcard(pattern)
    |> Enum.map(fn path ->
      path
      |> Path.basename(".db")
      |> String.replace_prefix("namespace_", "")
      |> String.replace_suffix("_#{env}", "")
    end)
    |> Enum.sort()
  end
  
  @doc """
  Checks if a namespace database file exists.
  """
  def exists?(namespace) when is_binary(namespace) do
    db_path = get_db_path(namespace)
    File.exists?(db_path)
  end
  
  @doc """
  Gets the database file path for a namespace.
  """
  def get_db_path(namespace) when is_binary(namespace) do
    # Validate namespace name
    unless namespace =~ ~r/^[a-zA-Z0-9_]+$/ do
      raise ArgumentError, "Invalid namespace name: #{namespace}. Only alphanumeric characters and underscores allowed."
    end
    
    env = get_env()
    data_dir = get_data_dir()
    Path.join(data_dir, "namespace_#{namespace}_#{env}.db")
  end
  
  defp get_data_dir do
    System.get_env("DATA_DIR", "data")
  end
  
  defp get_env do
    Application.get_env(:multidb, :env, Mix.env()) |> to_string()
  end
end
