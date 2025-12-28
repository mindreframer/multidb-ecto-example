defmodule Multidb.NamespaceIntegrationTest do
  use Multidb.DataCase
  
  alias Multidb.{Repo, User, NamespaceContext, Namespace}
  
  setup do
    # Create unique namespaces for each test
    ns1 = "test_ns1_#{System.unique_integer([:positive])}"
    ns2 = "test_ns2_#{System.unique_integer([:positive])}"
    
    # Create namespaces
    Namespace.create(ns1)
    Namespace.create(ns2)
    
    # For PostgreSQL in test mode, manually create tables
    if adapter() == :postgres do
      create_pg_tables_in_schema(ns1)
      create_pg_tables_in_schema(ns2)
    end
    
    # Clean up namespaces after test
    on_exit(fn ->
      NamespaceContext.delete()
      Namespace.delete(ns1)
      Namespace.delete(ns2)
    end)
    
    {:ok, ns1: ns1, ns2: ns2}
  end
  
  defp create_pg_tables_in_schema(schema) do
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
  
  describe "SQLite namespace isolation" do
    @tag :sqlite
    test "data is isolated between namespaces", %{ns1: ns1, ns2: ns2} do
      # Create users in namespace 1
      NamespaceContext.put(ns1)
      {:ok, user1} = Repo.insert(%User{name: "Alice", email: "alice@ns1.com"})
      assert user1.name == "Alice"
      
      # Verify we can query it
      users_ns1 = Repo.all(User)
      assert length(users_ns1) == 1
      assert hd(users_ns1).email == "alice@ns1.com"
      
      # Switch to namespace 2
      NamespaceContext.put(ns2)
      {:ok, _user2} = Repo.insert(%User{name: "Bob", email: "bob@ns2.com"})
      
      # Should only see namespace 2 data
      users_ns2 = Repo.all(User)
      assert length(users_ns2) == 1
      assert hd(users_ns2).email == "bob@ns2.com"
      
      # Switch back to namespace 1
      NamespaceContext.put(ns1)
      users_ns1_again = Repo.all(User)
      assert length(users_ns1_again) == 1
      assert hd(users_ns1_again).email == "alice@ns1.com"
    end
    
    @tag :sqlite
    test "with_namespace temporarily switches context", %{ns1: ns1, ns2: ns2} do
      NamespaceContext.put(ns1)
      Repo.insert(%User{name: "Alice", email: "alice@ns1.com"})
      
      # Temporarily switch to ns2
      NamespaceContext.with_namespace(ns2, fn ->
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
    
    @tag :sqlite
    test "CRUD operations work in namespace", %{ns1: ns1} do
      NamespaceContext.put(ns1)
      
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
    
    @tag :sqlite
    test "transactions work in namespace", %{ns1: ns1} do
      NamespaceContext.put(ns1)
      
      result = Repo.transaction(fn ->
        Repo.insert(%User{name: "David", email: "david@ns1.com"})
        Repo.insert(%User{name: "Eve", email: "eve@ns1.com"})
        :ok
      end)
      
      assert {:ok, :ok} = result
      assert length(Repo.all(User)) == 2
    end
    
    @tag :sqlite
    test "rollback works in namespace", %{ns1: ns1} do
      NamespaceContext.put(ns1)
      
      result = Repo.transaction(fn ->
        Repo.insert(%User{name: "Frank", email: "frank@ns1.com"})
        Repo.rollback(:oops)
      end)
      
      assert {:error, :oops} = result
      assert Repo.all(User) == []
    end
    
    @tag :sqlite
    test "aggregates work in namespace", %{ns1: ns1} do
      NamespaceContext.put(ns1)
      
      Repo.insert(%User{name: "User1", email: "u1@ns1.com", age: 20})
      Repo.insert(%User{name: "User2", email: "u2@ns1.com", age: 30})
      Repo.insert(%User{name: "User3", email: "u3@ns1.com", age: 40})
      
      count = Repo.aggregate(User, :count)
      assert count == 3
      
      avg_age = Repo.aggregate(User, :avg, :age)
      assert avg_age == 30.0
    end
    
    @tag :sqlite
    test "no namespace uses default database" do
      # No namespace set
      assert NamespaceContext.get() == nil
      
      # Should use the default test database
      {:ok, user} = Repo.insert(%User{name: "Default", email: "default@test.com"})
      assert user.id
      
      users = Repo.all(User)
      # May have data from other tests, but should at least have this one
      assert Enum.any?(users, &(&1.email == "default@test.com"))
    end
  end
  
  defp adapter do
    case Repo.active_repo() do
      Multidb.PostgresRepo -> :postgres
      Multidb.SqliteRepo -> :sqlite
    end
  end
end
