defmodule MultidbTest do
  use Multidb.DataCase

  alias Multidb.Accounts
  alias Multidb.Repo
  alias Multidb.User

  describe "Repo facade" do
    test "returns the correct active repo based on DB_ADAPTER" do
      active_repo = Repo.active_repo()
      
      case System.get_env("DB_ADAPTER", "sqlite") do
        "postgres" -> 
          assert active_repo == Multidb.PostgresRepo
        "sqlite" -> 
          assert active_repo == Multidb.SqliteRepo
      end
    end

    test "delegates basic operations correctly" do
      {:ok, user} = Repo.insert(%User{
        name: "Test User",
        email: "test@example.com",
        age: 25
      })

      assert user.id
      assert user.name == "Test User"

      # Test get
      retrieved = Repo.get(User, user.id)
      assert retrieved.email == "test@example.com"

      # Test all
      users = Repo.all(User)
      assert length(users) == 1

      # Test update
      changeset = User.changeset(user, %{age: 26})
      {:ok, updated} = Repo.update(changeset)
      assert updated.age == 26

      # Test delete
      {:ok, _deleted} = Repo.delete(user)
      assert Repo.all(User) == []
    end
  end

  describe "Accounts context" do
    test "creates a user" do
      {:ok, user} = Accounts.create_user(%{
        name: "Alice Johnson",
        email: "alice@example.com",
        age: 28
      })

      assert user.id
      assert user.name == "Alice Johnson"
      assert user.email == "alice@example.com"
      assert user.age == 28
    end

    test "validates required fields" do
      {:error, changeset} = Accounts.create_user(%{age: 30})
      
      assert changeset.errors[:name]
      assert changeset.errors[:email]
    end

    test "validates email format" do
      {:error, changeset} = Accounts.create_user(%{
        name: "Bob",
        email: "invalid-email"
      })

      assert changeset.errors[:email]
    end

    test "lists users" do
      {:ok, _user1} = Accounts.create_user(%{name: "User 1", email: "user1@example.com"})
      {:ok, _user2} = Accounts.create_user(%{name: "User 2", email: "user2@example.com"})

      users = Accounts.list_users()
      assert length(users) == 2
    end

    test "gets a user by id" do
      {:ok, user} = Accounts.create_user(%{name: "Test", email: "test@example.com"})
      
      found = Accounts.get_user!(user.id)
      assert found.id == user.id
      assert found.name == "Test"
    end

    test "gets user by email" do
      {:ok, user} = Accounts.create_user(%{
        name: "Alice",
        email: "alice@example.com"
      })

      found = Accounts.get_user_by_email("alice@example.com")
      assert found.id == user.id
      assert found.name == "Alice"
    end

    test "updates a user" do
      {:ok, user} = Accounts.create_user(%{
        name: "Bob",
        email: "bob@example.com",
        age: 25
      })

      {:ok, updated} = Accounts.update_user(user, %{age: 30})
      assert updated.age == 30
      assert updated.name == "Bob"
    end

    test "deletes a user" do
      {:ok, user} = Accounts.create_user(%{name: "Carol", email: "carol@example.com"})
      
      assert Accounts.count_users() == 1
      
      {:ok, _deleted} = Accounts.delete_user(user)
      
      assert Accounts.count_users() == 0
    end

    test "counts users" do
      assert Accounts.count_users() == 0

      {:ok, _user1} = Accounts.create_user(%{name: "User 1", email: "user1@example.com"})
      assert Accounts.count_users() == 1

      {:ok, _user2} = Accounts.create_user(%{name: "User 2", email: "user2@example.com"})
      assert Accounts.count_users() == 2
    end
  end

end
