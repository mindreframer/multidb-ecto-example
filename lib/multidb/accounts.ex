defmodule Multidb.Accounts do
  @moduledoc """
  The Accounts context - demonstrates database-agnostic operations.
  
  This module uses Multidb.Repo which automatically delegates to
  the correct backend (SQLite or PostgreSQL) at runtime.
  """

  import Ecto.Query, warn: false
  alias Multidb.Repo
  alias Multidb.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns the count of users.
  """
  def count_users do
    Repo.aggregate(User, :count)
  end

  @doc """
  Gets user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end
end
