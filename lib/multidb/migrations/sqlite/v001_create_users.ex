defmodule Multidb.Migrations.Sqlite.V001CreateUsers do
  use Ecto.Migration

  def up do
    # SQLite doesn't support :bigint for timestamps, use :integer
    # Also uses create_if_not_exists for idempotency
    create_if_not_exists table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :age, :integer

      # Note: timestamps() macro adds naive_datetime fields
      # For SQLite compatibility, you might want to use :integer for Unix timestamps
      timestamps()
    end

    create_if_not_exists unique_index(:users, [:email])
  end

  def down do
    drop_if_exists table(:users)
  end
end
