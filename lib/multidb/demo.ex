defmodule Multidb.Demo do
  @moduledoc """
  Demo module to showcase runtime database switching.
  
  ## Usage
  
  # Using SQLite (default):
  $ iex -S mix
  iex> Multidb.Demo.run()
  
  # Using PostgreSQL:
  $ DB_ADAPTER=postgres iex -S mix
  iex> Multidb.Demo.run()
  """

  alias Multidb.Accounts
  alias Multidb.Repo

  def run do
    active_repo = Repo.active_repo()
    adapter = case active_repo do
      Multidb.PostgresRepo -> "PostgreSQL"
      Multidb.SqliteRepo -> "SQLite"
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Multidb Demo - Using #{adapter} (#{inspect(active_repo)})")
    IO.puts(String.duplicate("=", 60) <> "\n")

    # Create some users
    IO.puts("Creating users...")
    {:ok, user1} = Accounts.create_user(%{
      name: "Alice Johnson",
      email: "alice@example.com",
      age: 28
    })
    IO.puts("  ✓ Created: #{user1.name} (ID: #{user1.id})")

    {:ok, user2} = Accounts.create_user(%{
      name: "Bob Smith",
      email: "bob@example.com",
      age: 35
    })
    IO.puts("  ✓ Created: #{user2.name} (ID: #{user2.id})")

    {:ok, user3} = Accounts.create_user(%{
      name: "Carol White",
      email: "carol@example.com",
      age: 42
    })
    IO.puts("  ✓ Created: #{user3.name} (ID: #{user3.id})")

    # List all users
    IO.puts("\nListing all users...")
    users = Accounts.list_users()
    Enum.each(users, fn user ->
      IO.puts("  - #{user.name} (#{user.email}) - Age: #{user.age}")
    end)

    # Count users
    count = Accounts.count_users()
    IO.puts("\nTotal users: #{count}")

    # Find user by email
    IO.puts("\nFinding user by email (alice@example.com)...")
    found_user = Accounts.get_user_by_email("alice@example.com")
    IO.puts("  ✓ Found: #{found_user.name}")

    # Update user
    IO.puts("\nUpdating Alice's age to 29...")
    {:ok, updated_user} = Accounts.update_user(user1, %{age: 29})
    IO.puts("  ✓ Updated: #{updated_user.name} - New age: #{updated_user.age}")

    # Delete user
    IO.puts("\nDeleting Bob...")
    {:ok, _deleted} = Accounts.delete_user(user2)
    IO.puts("  ✓ Deleted")

    # Final count
    final_count = Accounts.count_users()
    IO.puts("\nFinal user count: #{final_count}")

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Demo completed successfully with #{adapter}!")
    IO.puts(String.duplicate("=", 60) <> "\n")

    :ok
  end

  def info do
    active_repo = Repo.active_repo()
    adapter = case active_repo do
      Multidb.PostgresRepo -> "PostgreSQL"
      Multidb.SqliteRepo -> "SQLite"
    end

    %{
      adapter: adapter,
      repo_module: active_repo,
      env_var: System.get_env("DB_ADAPTER", "sqlite")
    }
  end
end
