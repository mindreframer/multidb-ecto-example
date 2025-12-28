defmodule Multidb.NamespaceDemo do
  @moduledoc """
  Demo module to showcase namespace isolation.
  
  ## Usage (PostgreSQL only)
  
      DB_ADAPTER=postgres iex -S mix
      iex> Multidb.NamespaceDemo.run()
  """
  
  alias Multidb.{Repo, User, Namespace, NamespaceContext}
  
  def run do
    adapter = Namespace.get_adapter()
    
    IO.puts("\n#{String.duplicate("=", 70)}")
    IO.puts("Multidb Namespace Demo - Using #{adapter |> to_string() |> String.upcase()}")
    IO.puts("#{String.duplicate("=", 70)}\n")
    
    case adapter do
      :postgres -> run_postgres_demo()
      :sqlite -> run_sqlite_demo()
    end
  end
  
  defp run_postgres_demo do
    IO.puts("Creating namespaces...")
    
    # Clean up any existing demo namespaces
    Namespace.delete("demo_acme")
    Namespace.delete("demo_globex")
    
    # Create two tenant namespaces
    Namespace.create("demo_acme")
    Namespace.create("demo_globex")
    
    IO.puts("  ✓ Created namespaces: demo_acme, demo_globex\n")
    
    # Work in ACME namespace
    IO.puts("Working in ACME namespace...")
    NamespaceContext.put("demo_acme")
    
    {:ok, alice} = Repo.insert(%User{name: "Alice", email: "alice@acme.com", age: 28})
    {:ok, bob} = Repo.insert(%User{name: "Bob", email: "bob@acme.com", age: 35})
    
    IO.puts("  ✓ Created users in ACME namespace")
    IO.puts("  - #{alice.name} (#{alice.email})")
    IO.puts("  - #{bob.name} (#{bob.email})")
    
    users_acme = Repo.all(User)
    IO.puts("  ✓ ACME has #{length(users_acme)} users\n")
    
    # Work in Globex namespace
    IO.puts("Working in Globex namespace...")
    NamespaceContext.put("demo_globex")
    
    {:ok, charlie} = Repo.insert(%User{name: "Charlie", email: "charlie@globex.com", age: 42})
    
    IO.puts("  ✓ Created users in Globex namespace")
    IO.puts("  - #{charlie.name} (#{charlie.email})")
    
    users_globex = Repo.all(User)
    IO.puts("  ✓ Globex has #{length(users_globex)} users\n")
    
    # Demonstrate isolation
    IO.puts("Demonstrating namespace isolation...")
    
    NamespaceContext.put("demo_acme")
    acme_count = length(Repo.all(User))
    IO.puts("  ✓ ACME namespace: #{acme_count} users")
    
    NamespaceContext.put("demo_globex")
    globex_count = length(Repo.all(User))
    IO.puts("  ✓ Globex namespace: #{globex_count} users")
    
    IO.puts("\n  ✓ Data is completely isolated between namespaces!\n")
    
    # Demonstrate with_namespace
    IO.puts("Using with_namespace for temporary context switch...")
    
    NamespaceContext.put("demo_acme")
    
    NamespaceContext.with_namespace("demo_globex", fn ->
      users = Repo.all(User)
      IO.puts("  ✓ Inside with_namespace block: #{length(users)} Globex users")
    end)
    
    users = Repo.all(User)
    IO.puts("  ✓ After with_namespace block: #{length(users)} ACME users (context restored)\n")
    
    # List all namespaces
    IO.puts("All namespaces in the system:")
    Namespace.list()
    |> Enum.each(fn ns ->
      IO.puts("  - #{ns}")
    end)
    
    IO.puts("\n#{String.duplicate("=", 70)}")
    IO.puts("Demo completed successfully!")
    IO.puts("#{String.duplicate("=", 70)}\n")
    
    # Clean up
    NamespaceContext.delete()
    Namespace.delete("demo_acme")
    Namespace.delete("demo_globex")
    
    :ok
  end
  
  defp run_sqlite_demo do
    IO.puts("Running SQLite demo (using separate database files per namespace)...\n")
    
    # Same demo as PostgreSQL but with SQLite
    run_postgres_demo()
  end
end
