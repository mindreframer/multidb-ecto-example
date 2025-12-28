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

  def all(queryable, opts \\ []) do
    active_repo().all(queryable, opts)
  end

  def get(queryable, id, opts \\ []) do
    active_repo().get(queryable, id, opts)
  end

  def get!(queryable, id, opts \\ []) do
    active_repo().get!(queryable, id, opts)
  end

  def get_by(queryable, clauses, opts \\ []) do
    active_repo().get_by(queryable, clauses, opts)
  end

  def get_by!(queryable, clauses, opts \\ []) do
    active_repo().get_by!(queryable, clauses, opts)
  end

  def one(queryable, opts \\ []) do
    active_repo().one(queryable, opts)
  end

  def one!(queryable, opts \\ []) do
    active_repo().one!(queryable, opts)
  end

  def insert(struct_or_changeset, opts \\ []) do
    active_repo().insert(struct_or_changeset, opts)
  end

  def insert!(struct_or_changeset, opts \\ []) do
    active_repo().insert!(struct_or_changeset, opts)
  end

  def update(changeset, opts \\ []) do
    active_repo().update(changeset, opts)
  end

  def update!(changeset, opts \\ []) do
    active_repo().update!(changeset, opts)
  end

  def delete(struct_or_changeset, opts \\ []) do
    active_repo().delete(struct_or_changeset, opts)
  end

  def delete!(struct_or_changeset, opts \\ []) do
    active_repo().delete!(struct_or_changeset, opts)
  end

  def insert_all(schema_or_source, entries, opts \\ []) do
    active_repo().insert_all(schema_or_source, entries, opts)
  end

  def update_all(queryable, updates, opts \\ []) do
    active_repo().update_all(queryable, updates, opts)
  end

  def delete_all(queryable, opts \\ []) do
    active_repo().delete_all(queryable, opts)
  end

  def transaction(fun_or_multi, opts \\ []) do
    active_repo().transaction(fun_or_multi, opts)
  end

  def rollback(value) do
    active_repo().rollback(value)
  end

  def aggregate(queryable, aggregate, opts \\ []) do
    active_repo().aggregate(queryable, aggregate, opts)
  end

  def exists?(queryable, opts \\ []) do
    active_repo().exists?(queryable, opts)
  end

  def preload(struct_or_structs, preloads, opts \\ []) do
    active_repo().preload(struct_or_structs, preloads, opts)
  end

  # For migrations and other tools that need the actual repo module
  defdelegate __adapter__, to: Multidb.SqliteRepo
  defdelegate config, to: Multidb.SqliteRepo
end
