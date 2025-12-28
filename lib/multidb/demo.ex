defmodule Multidb.Demo do
  @moduledoc """
  Demo module to showcase runtime database switching.
  
  ## Usage
  
      # SQLite (default):
      iex -S mix
      iex> Multidb.Demo.run()
      
      # PostgreSQL:
      DB_ADAPTER=postgres iex -S mix
      iex> Multidb.Demo.run()
  """

  alias Multidb.Accounts
  alias Multidb.Repo

  def run do
    adapter_name = case Repo.active_repo() do
      Multidb.PostgresRepo -> "PostgreSQL"
      Multidb.SqliteRepo -> "SQLite"
    end

    IO.puts("\n#{String.duplicate("=", 60)}")
    IO.puts("Multidb Demo - Using #{adapter_name}")
    IO.puts("#{String.duplicate("=", 60)}\n")

    # Create users
    IO.puts("Creating users...")
    {:ok, alice} = Accounts.create_user(%{name: "Alice", email: "alice@example.com", age: 28})
    {:ok, bob} = Accounts.create_user(%{name: "Bob", email: "bob@example.com", age: 35})
    {:ok, carol} = Accounts.create_user(%{name: "Carol", email: "carol@example.com", age: 42})
    
    IO.puts("  ✓ Created: #{alice.name}, #{bob.name}, #{carol.name}")

    # List users
    IO.puts("\nListing all users:")
    Enum.each(Accounts.list_users(), fn user ->
      IO.puts("  - #{user.name} (#{user.email}) - Age: #{user.age}")
    end)

    IO.puts("\nTotal users: #{Accounts.count_users()}")

    # Query by email
    IO.puts("\nFinding user by email (alice@example.com):")
    found = Accounts.get_user_by_email("alice@example.com")
    IO.puts("  ✓ Found: #{found.name}")

    # Update
    IO.puts("\nUpdating Alice's age to 29:")
    {:ok, updated} = Accounts.update_user(alice, %{age: 29})
    IO.puts("  ✓ Updated: #{updated.name} - New age: #{updated.age}")

    # Delete
    IO.puts("\nDeleting Bob:")
    {:ok, _} = Accounts.delete_user(bob)
    IO.puts("  ✓ Deleted")

    IO.puts("\nFinal user count: #{Accounts.count_users()}")
    IO.puts("\n#{String.duplicate("=", 60)}")
    IO.puts("Demo completed successfully with #{adapter_name}!")
    IO.puts("#{String.duplicate("=", 60)}\n")

    :ok
  end
end
