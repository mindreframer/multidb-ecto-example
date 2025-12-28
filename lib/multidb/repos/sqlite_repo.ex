defmodule Multidb.SqliteRepo do
  @moduledoc """
  Ecto Repo for SQLite database.
  """
  use Ecto.Repo,
    otp_app: :multidb,
    adapter: Ecto.Adapters.SQLite3
end
