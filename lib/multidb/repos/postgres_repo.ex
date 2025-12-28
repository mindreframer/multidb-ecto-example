defmodule Multidb.PostgresRepo do
  @moduledoc """
  Ecto Repo for PostgreSQL database.
  """
  use Ecto.Repo,
    otp_app: :multidb,
    adapter: Ecto.Adapters.Postgres
end
