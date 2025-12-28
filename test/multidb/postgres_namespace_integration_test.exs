defmodule Multidb.PostgresNamespaceIntegrationTest do
  use Multidb.DataCase
  
  alias Multidb.{Repo, User, NamespaceContext}
  alias Multidb.Adapters.PostgresNamespace
  
  @ns1 "test_pg_ns1"
  @ns2 "test_pg_ns2"
  
  setup do
    # Only run for postgres
    if adapter() != :postgres do
      :ok
    else
      # Clean up namespaces before and after test
      on_exit(fn ->
        NamespaceContext.delete()
        PostgresNamespace.delete(@ns1)
        PostgresNamespace.delete(@ns2)
      end)
      
      # Create test namespaces (without running migrations)
      PostgresNamespace.delete(@ns1)
      PostgresNamespace.delete(@ns2)
      PostgresNamespace.create(@ns1, skip_migrations: true)
      PostgresNamespace.create(@ns2, skip_migrations: true)
      
      # Note: Migrations should be run outside tests (in test script)
      # For now, we'll create tables manually in each test schema
      create_tables_in_schema(@ns1)
      create_tables_in_schema(@ns2)
      
      :ok
    end
  end
  
  defp create_tables_in_schema(schema) do
    # Manually create the users table in the schema
    # This avoids the Sandbox transaction issue with migrations
    alias Multidb.PostgresRepo
    
    PostgresRepo.query!("""
    CREATE TABLE IF NOT EXISTS #{schema}.users (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      age INTEGER,
      inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
    """)
    
    PostgresRepo.query!("""
    CREATE UNIQUE INDEX IF NOT EXISTS users_email_index ON #{schema}.users (email)
    """)
  end
  
  describe "PostgreSQL namespace isolation" do
    @tag :postgres
    test "data is isolated between namespaces" do
      # Create users in namespace 1
      NamespaceContext.put(@ns1)
      {:ok, user1} = Repo.insert(%User{name: "Alice", email: "alice@ns1.com"})
      assert user1.name == "Alice"
      
      # Verify we can query it
      users_ns1 = Repo.all(User)
      assert length(users_ns1) == 1
      assert hd(users_ns1).email == "alice@ns1.com"
      
      # Switch to namespace 2
      NamespaceContext.put(@ns2)
      {:ok, _user2} = Repo.insert(%User{name: "Bob", email: "bob@ns2.com"})
      
      # Should only see namespace 2 data
      users_ns2 = Repo.all(User)
      assert length(users_ns2) == 1
      assert hd(users_ns2).email == "bob@ns2.com"
      
      # Switch back to namespace 1
      NamespaceContext.put(@ns1)
      users_ns1_again = Repo.all(User)
      assert length(users_ns1_again) == 1
      assert hd(users_ns1_again).email == "alice@ns1.com"
    end
    
    @tag :postgres
    test "with_namespace temporarily switches context" do
      NamespaceContext.put(@ns1)
      Repo.insert(%User{name: "Alice", email: "alice@ns1.com"})
      
      # Temporarily switch to ns2
      NamespaceContext.with_namespace(@ns2, fn ->
        Repo.insert(%User{name: "Bob", email: "bob@ns2.com"})
        
        users = Repo.all(User)
        assert length(users) == 1
        assert hd(users).name == "Bob"
      end)
      
      # Back to ns1
      users = Repo.all(User)
      assert length(users) == 1
      assert hd(users).name == "Alice"
    end
    
    @tag :postgres
    test "CRUD operations work in namespace" do
      NamespaceContext.put(@ns1)
      
      # Create
      {:ok, user} = Repo.insert(%User{name: "Charlie", email: "charlie@ns1.com", age: 25})
      assert user.id
      
      # Read
      found = Repo.get(User, user.id)
      assert found.name == "Charlie"
      
      found_by_email = Repo.get_by(User, email: "charlie@ns1.com")
      assert found_by_email.id == user.id
      
      # Update
      changeset = User.changeset(user, %{age: 26})
      {:ok, updated} = Repo.update(changeset)
      assert updated.age == 26
      
      # Delete
      {:ok, deleted} = Repo.delete(user)
      assert deleted.id == user.id
      
      assert Repo.all(User) == []
    end
    
    @tag :postgres
    test "transactions work in namespace" do
      NamespaceContext.put(@ns1)
      
      result = Repo.transaction(fn ->
        Repo.insert(%User{name: "David", email: "david@ns1.com"})
        Repo.insert(%User{name: "Eve", email: "eve@ns1.com"})
        :ok
      end)
      
      assert {:ok, :ok} = result
      assert length(Repo.all(User)) == 2
    end
  end
  
  defp adapter do
    case Repo.active_repo() do
      Multidb.PostgresRepo -> :postgres
      Multidb.SqliteRepo -> :sqlite
    end
  end
end
