defmodule Multidb.Repo do
  @moduledoc """
  Dynamic Repo facade that delegates to the appropriate backend
  based on the DB_ADAPTER environment variable.
  
  Set DB_ADAPTER=postgres or DB_ADAPTER=sqlite at boot time.
  Defaults to SQLite if not set.
  """

  @persistent_term_key {__MODULE__, :active_repo}

  @doc """
  Initialize the active repo selection and store it in :persistent_term.
  This should be called once during application startup.
  """
  def init do
    repo = case System.get_env("DB_ADAPTER", "sqlite") do
      "postgres" -> Multidb.PostgresRepo
      "sqlite" -> Multidb.SqliteRepo
      other -> 
        raise """
        Invalid DB_ADAPTER: #{other}
        Valid values are: postgres, sqlite
        """
    end
    
    :persistent_term.put(@persistent_term_key, repo)
    repo
  end

  @doc """
  Returns the active repo module based on boot-time configuration.
  Falls back to reading from env if not yet initialized (e.g., in Mix tasks).
  """
  def active_repo do
    case :persistent_term.get(@persistent_term_key, nil) do
      nil -> init()  # Not initialized yet, initialize now
      repo -> repo
    end
  end

  # Delegate common Ecto.Repo functions to the active repo
  # This allows Multidb.Repo to be used as a drop-in replacement
  # Namespace is automatically resolved from process context

  def all(queryable, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn ->
      repo.all(queryable, opts)
    end)
  end

  def get(queryable, id, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.get(queryable, id, opts) end)
  end

  def get!(queryable, id, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.get!(queryable, id, opts) end)
  end

  def get_by(queryable, clauses, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.get_by(queryable, clauses, opts) end)
  end

  def get_by!(queryable, clauses, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.get_by!(queryable, clauses, opts) end)
  end

  def one(queryable, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.one(queryable, opts) end)
  end

  def one!(queryable, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.one!(queryable, opts) end)
  end

  def insert(struct_or_changeset, opts \\ []) do
    {repo, struct_or_changeset} = prepare_mutation(struct_or_changeset)
    with_dynamic_repo(repo, fn -> repo.insert(struct_or_changeset, opts) end)
  end

  def insert!(struct_or_changeset, opts \\ []) do
    {repo, struct_or_changeset} = prepare_mutation(struct_or_changeset)
    with_dynamic_repo(repo, fn -> repo.insert!(struct_or_changeset, opts) end)
  end

  def update(changeset, opts \\ []) do
    {repo, changeset} = prepare_mutation(changeset)
    with_dynamic_repo(repo, fn -> repo.update(changeset, opts) end)
  end

  def update!(changeset, opts \\ []) do
    {repo, changeset} = prepare_mutation(changeset)
    with_dynamic_repo(repo, fn -> repo.update!(changeset, opts) end)
  end

  def delete(struct_or_changeset, opts \\ []) do
    {repo, struct_or_changeset} = prepare_mutation(struct_or_changeset)
    with_dynamic_repo(repo, fn -> repo.delete(struct_or_changeset, opts) end)
  end

  def delete!(struct_or_changeset, opts \\ []) do
    {repo, struct_or_changeset} = prepare_mutation(struct_or_changeset)
    with_dynamic_repo(repo, fn -> repo.delete!(struct_or_changeset, opts) end)
  end

  def insert_all(schema_or_source, entries, opts \\ []) do
    repo = get_repo_for_namespace()
    # For insert_all, we need to handle the schema/source differently
    schema_or_source = apply_namespace_to_source(schema_or_source)
    with_dynamic_repo(repo, fn -> repo.insert_all(schema_or_source, entries, opts) end)
  end

  def update_all(queryable, updates, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.update_all(queryable, updates, opts) end)
  end

  def delete_all(queryable, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.delete_all(queryable, opts) end)
  end

  def transaction(fun_or_multi, opts \\ []) do
    repo = get_repo_for_namespace()
    with_dynamic_repo(repo, fn -> repo.transaction(fun_or_multi, opts) end)
  end

  def rollback(value) do
    repo = get_repo_for_namespace()
    with_dynamic_repo(repo, fn -> repo.rollback(value) end)
  end

  def aggregate(queryable, aggregate, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.aggregate(queryable, aggregate, opts) end)
  end

  def exists?(queryable, opts \\ []) do
    {repo, queryable} = prepare_query(queryable)
    with_dynamic_repo(repo, fn -> repo.exists?(queryable, opts) end)
  end

  def preload(struct_or_structs, preloads, opts \\ []) do
    repo = get_repo_for_namespace()
    with_dynamic_repo(repo, fn -> repo.preload(struct_or_structs, preloads, opts) end)
  end

  # For migrations and other tools that need the actual repo module
  defdelegate __adapter__, to: Multidb.SqliteRepo
  defdelegate config, to: Multidb.SqliteRepo

  ## Private Functions - Namespace Support
  
  # Automatically injects namespace into queries
  defp prepare_query(queryable) do
    namespace = Multidb.NamespaceContext.get()
    repo = get_repo_for_namespace(namespace)
    queryable = apply_namespace_to_query(queryable, namespace)
    {repo, queryable}
  end
  
  # Automatically handles namespace for mutations (insert/update/delete)
  defp prepare_mutation(struct_or_changeset) do
    namespace = Multidb.NamespaceContext.get()
    repo = get_repo_for_namespace(namespace)
    struct_or_changeset = apply_namespace_to_struct(struct_or_changeset, namespace)
    {repo, struct_or_changeset}
  end
  
  defp get_repo_for_namespace do
    get_repo_for_namespace(Multidb.NamespaceContext.get())
  end
  
  defp get_repo_for_namespace(nil), do: active_repo()
  defp get_repo_for_namespace(namespace) when is_binary(namespace) do
    case active_repo() do
      Multidb.PostgresRepo -> 
        # Same repo, namespace handled via prefix
        Multidb.PostgresRepo
        
      Multidb.SqliteRepo ->
        # Get the namespace-specific repo instance name
        # The actual repo will be set via put_dynamic_repo
        Multidb.SqliteRepo
    end
  end
  
  # Wraps repo calls with proper dynamic repo context for SQLite namespaces
  defp with_dynamic_repo(repo, fun) do
    namespace = Multidb.NamespaceContext.get()
    
    case {repo, namespace} do
      {Multidb.SqliteRepo, ns} when is_binary(ns) ->
        # For SQLite namespaces, set the dynamic repo to the namespace instance
        repo_name = Multidb.NamespaceRegistry.get_or_start_repo(namespace)
        repo.put_dynamic_repo(repo_name)
        
        try do
          fun.()
        after
          # Reset to default repo
          repo.put_dynamic_repo(repo)
        end
        
      _ ->
        # For PostgreSQL or no namespace, just call directly
        fun.()
    end
  end
  
  defp apply_namespace_to_query(queryable, nil), do: queryable
  defp apply_namespace_to_query(queryable, namespace) when is_binary(namespace) do
    case active_repo() do
      Multidb.PostgresRepo ->
        # Add schema prefix for Postgres
        # We need to use Ecto.Queryable.to_query and manually set the prefix
        query = Ecto.Queryable.to_query(queryable)
        %{query | prefix: namespace}
        
      Multidb.SqliteRepo ->
        # SQLite uses different DB files, no prefix needed
        queryable
    end
  end
  
  defp apply_namespace_to_struct(struct, nil), do: struct
  defp apply_namespace_to_struct(%Ecto.Changeset{} = changeset, namespace) when is_binary(namespace) do
    case active_repo() do
      Multidb.PostgresRepo ->
        # Put the prefix in the changeset's data meta
        %{changeset | data: put_struct_prefix(changeset.data, namespace)}
        
      Multidb.SqliteRepo ->
        # No prefix needed for SQLite
        changeset
    end
  end
  defp apply_namespace_to_struct(struct, namespace) when is_binary(namespace) do
    case active_repo() do
      Multidb.PostgresRepo ->
        put_struct_prefix(struct, namespace)
        
      Multidb.SqliteRepo ->
        struct
    end
  end
  
  defp put_struct_prefix(%{__meta__: meta} = struct, prefix) do
    %{struct | __meta__: %{meta | prefix: prefix}}
  end
  defp put_struct_prefix(struct, _prefix), do: struct
  
  defp apply_namespace_to_source(source, namespace \\ nil)
  defp apply_namespace_to_source(source, nil) do
    apply_namespace_to_source(source, Multidb.NamespaceContext.get())
  end
  defp apply_namespace_to_source(source, namespace) when is_binary(namespace) do
    case active_repo() do
      Multidb.PostgresRepo ->
        {source, prefix: namespace}
        
      Multidb.SqliteRepo ->
        source
    end
  end
  defp apply_namespace_to_source(source, _), do: source
end
