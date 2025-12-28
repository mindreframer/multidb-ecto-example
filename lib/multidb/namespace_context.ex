defmodule Multidb.NamespaceContext do
  @moduledoc """
  Manages the current namespace for database operations.
  
  The namespace is stored in the process dictionary, making it
  transparent to all database operations within the same process.
  
  ## Examples
  
      # Set namespace for current process
      NamespaceContext.put("tenant_acme")
      
      # Get current namespace
      NamespaceContext.get()  # => "tenant_acme"
      
      # Execute with temporary namespace
      NamespaceContext.with_namespace("tenant_xyz", fn ->
        # Operations here use tenant_xyz
      end)
      # Previous namespace restored
  """
  
  @namespace_key {__MODULE__, :current_namespace}
  
  @doc """
  Sets the namespace for the current process.
  All database operations in this process will use this namespace.
  """
  def put(namespace) when is_binary(namespace) do
    Process.put(@namespace_key, namespace)
  end
  
  @doc """
  Gets the current namespace for this process.
  Returns nil if no namespace is set (uses default).
  """
  def get do
    Process.get(@namespace_key)
  end
  
  @doc """
  Clears the namespace for the current process.
  """
  def delete do
    Process.delete(@namespace_key)
  end
  
  @doc """
  Executes a function within a specific namespace context.
  Restores the previous namespace after execution.
  """
  def with_namespace(namespace, fun) when is_function(fun, 0) do
    previous = get()
    
    try do
      put(namespace)
      fun.()
    after
      case previous do
        nil -> delete()
        prev -> put(prev)
      end
    end
  end
end
