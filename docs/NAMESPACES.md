# Namespace Support Guide

## Overview

Namespaces provide complete data isolation for multi-tenant applications. Each namespace has its own isolated set of tables and data.

**Status:**
- ✅ **PostgreSQL:** Fully supported (uses native schemas)
- ✅ **SQLite:** Fully supported (uses separate database files)

## Quick Start

### 1. Setup

```bash
# Works with both SQLite (default) and PostgreSQL
mix multidb.reset

# Or explicitly set adapter
export DB_ADAPTER=postgres  # or sqlite
mix multidb.reset

# Start shell
iex -S mix
```

### 2. Create Namespaces

```elixir
alias Multidb.Namespace

# Create namespaces (PostgreSQL schemas)
Namespace.create("tenant_acme")
Namespace.create("tenant_globex")

# List namespaces
Namespace.list()
# => ["tenant_acme", "tenant_globex"]

# Check if exists
Namespace.exists?("tenant_acme")
# => true
```

### 3. Use Namespaces

```elixir
alias Multidb.{NamespaceContext, Repo, User}

# Set namespace for current process
NamespaceContext.put("tenant_acme")

# All operations now use this namespace
{:ok, user} = Repo.insert(%User{name: "Alice", email: "alice@acme.com"})
users = Repo.all(User)  # Only sees tenant_acme data

# Switch to different namespace
NamespaceContext.put("tenant_globex")
{:ok, user} = Repo.insert(%User{name: "Bob", email: "bob@globex.com"})
users = Repo.all(User)  # Only sees tenant_globex data
```

### 4. Temporary Context Switch

```elixir
# Main namespace
NamespaceContext.put("tenant_acme")

# Temporarily work in different namespace
result = NamespaceContext.with_namespace("tenant_globex", fn ->
  # All operations in this block use tenant_globex
  Repo.all(User)
end)

# Automatically restored to tenant_acme
```

## API Reference

### Namespace Management

```elixir
# Create namespace
Namespace.create("tenant_name")
# => :ok | {:error, reason}

# Delete namespace (destructive!)
Namespace.delete("tenant_name")
# => :ok | {:error, reason}

# List all namespaces
Namespace.list()
# => ["namespace1", "namespace2", ...]

# Check existence
Namespace.exists?("tenant_name")
# => true | false

# Get current adapter
Namespace.get_adapter()
# => :postgres | :sqlite
```

### Context Management

```elixir
# Set namespace for current process
NamespaceContext.put("tenant_name")
# => "tenant_name"

# Get current namespace
NamespaceContext.get()
# => "tenant_name" | nil

# Clear namespace
NamespaceContext.delete()
# => nil

# Temporary context switch
NamespaceContext.with_namespace("temp_namespace", fn ->
  # Code here uses temp_namespace
  :ok
end)
# Previous namespace automatically restored
```

## Phoenix Integration

### Plug for Subdomain-Based Tenancy

```elixir
defmodule MyAppWeb.TenantPlug do
  @moduledoc """
  Extracts tenant from subdomain and sets namespace context.
  
  Example: acme.myapp.com -> namespace "acme"
  """
  
  import Plug.Conn
  alias Multidb.NamespaceContext
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    tenant = extract_tenant(conn)
    
    # Set namespace for this request process
    NamespaceContext.put(tenant)
    
    # Optionally store in conn assigns for easy access
    assign(conn, :current_tenant, tenant)
  end
  
  defp extract_tenant(conn) do
    case String.split(conn.host, ".") do
      [subdomain, _domain, _tld] -> subdomain
      [subdomain | _] -> subdomain
      _ -> "default"
    end
  end
end
```

### Add to Router

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MyAppWeb.TenantPlug  # <-- Add here
  end

  # All routes in browser pipeline automatically namespaced!
  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :index
    resources "/users", UserController
  end
end
```

### Header-Based Tenancy

```elixir
defmodule MyAppWeb.TenantPlug do
  import Plug.Conn
  alias Multidb.NamespaceContext
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    tenant = 
      get_req_header(conn, "x-tenant-id")
      |> List.first()
      |> || "default"
    
    NamespaceContext.put(tenant)
    assign(conn, :current_tenant, tenant)
  end
end
```

### Session-Based Tenancy

```elixir
defmodule MyAppWeb.TenantPlug do
  import Plug.Conn
  alias Multidb.NamespaceContext
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    # Assumes tenant_id stored in session after login
    tenant = get_session(conn, :tenant_id) || "default"
    
    NamespaceContext.put(tenant)
    assign(conn, :current_tenant, tenant)
  end
end
```

## Testing

### Test Setup

```elixir
defmodule MyApp.FeatureTest do
  use MyApp.DataCase
  
  alias Multidb.{Namespace, NamespaceContext}
  
  setup do
    # Create test namespace
    namespace = "test_#{System.unique_integer([:positive])}"
    Namespace.create(namespace)
    
    # Set for all tests in this module
    NamespaceContext.put(namespace)
    
    # Clean up after test
    on_exit(fn ->
      NamespaceContext.delete()
      Namespace.delete(namespace)
    end)
    
    {:ok, namespace: namespace}
  end
  
  test "creates user in isolated namespace", %{namespace: namespace} do
    {:ok, user} = Accounts.create_user(%{name: "Alice", email: "alice@test.com"})
    
    # User exists in this namespace
    assert Repo.get(User, user.id)
    
    # But not in a different namespace
    NamespaceContext.with_namespace("other", fn ->
      refute Repo.get(User, user.id)
    end)
  end
end
```

### Testing Isolation

```elixir
test "namespaces are isolated" do
  ns1 = "test_ns1_#{System.unique_integer([:positive])}"
  ns2 = "test_ns2_#{System.unique_integer([:positive])}"
  
  Namespace.create(ns1)
  Namespace.create(ns2)
  
  # Create data in ns1
  NamespaceContext.put(ns1)
  Accounts.create_user(%{name: "Alice", email: "alice@ns1.com"})
  
  # Create data in ns2
  NamespaceContext.put(ns2)
  Accounts.create_user(%{name: "Bob", email: "bob@ns2.com"})
  
  # Verify isolation
  NamespaceContext.put(ns1)
  users = Repo.all(User)
  assert length(users) == 1
  assert hd(users).name == "Alice"
  
  NamespaceContext.put(ns2)
  users = Repo.all(User)
  assert length(users) == 1
  assert hd(users).name == "Bob"
end
```

## How It Works

### Process Dictionary

The namespace is stored in the process dictionary, making it available to all function calls in that process without explicit passing:

```elixir
# Under the hood
Process.put({Multidb.NamespaceContext, :current_namespace}, "tenant_acme")

# Retrieved automatically by Repo
namespace = Process.get({Multidb.NamespaceContext, :current_namespace})
```

### PostgreSQL Implementation

```sql
-- Create namespace
CREATE SCHEMA IF NOT EXISTS tenant_acme;

-- Create tables in schema
CREATE TABLE tenant_acme.users (
  id SERIAL PRIMARY KEY,
  name TEXT,
  email TEXT
);

-- Queries automatically prefixed
SELECT * FROM tenant_acme.users WHERE email = 'alice@acme.com';
```

### Query Transformation

```elixir
# Your code
Repo.all(User)

# What happens internally when namespace is "tenant_acme"
queryable = Ecto.Queryable.to_query(User)
queryable = %{queryable | prefix: "tenant_acme"}
Repo.all(queryable)

# Resulting SQL
SELECT * FROM tenant_acme.users;
```

## Best Practices

### 1. Set Namespace Early

Set the namespace as early as possible in the request lifecycle:

```elixir
# Good: In plug
plug MyAppWeb.TenantPlug

# Good: In LiveView mount
def mount(_params, %{"tenant_id" => tenant}, socket) do
  NamespaceContext.put(tenant)
  # ...
end
```

### 2. Never Hardcode Namespaces

```elixir
# Bad
NamespaceContext.put("tenant_acme")
Accounts.create_user(attrs)

# Good
tenant = conn.assigns[:current_tenant]
NamespaceContext.put(tenant)
Accounts.create_user(attrs)
```

### 3. Clean Up in Tests

Always clean up namespaces in test teardown:

```elixir
setup do
  on_exit(fn ->
    NamespaceContext.delete()
    # Clean up test namespaces
  end)
end
```

### 4. Validate Namespace Access

```elixir
defmodule MyAppWeb.TenantPlug do
  def call(conn, _opts) do
    tenant = extract_tenant(conn)
    user = conn.assigns[:current_user]
    
    # Ensure user has access to this tenant
    if has_access?(user, tenant) do
      NamespaceContext.put(tenant)
      conn
    else
      conn
      |> put_status(:forbidden)
      |> halt()
    end
  end
end
```

## Troubleshooting

### "SQLite namespace support is not yet implemented"

You're trying to use namespaces with SQLite. Currently only PostgreSQL is supported.

**Solution:** Use PostgreSQL:
```bash
DB_ADAPTER=postgres mix multidb.reset
DB_ADAPTER=postgres iex -S mix
```

### Namespace not found

Make sure the namespace exists before using it:

```elixir
if not Namespace.exists?("tenant_acme") do
  Namespace.create("tenant_acme")
end

NamespaceContext.put("tenant_acme")
```

### Data appearing in wrong namespace

Check that namespace is set in the current process:

```elixir
# Debug current namespace
IO.inspect(NamespaceContext.get(), label: "Current namespace")
```

### Namespace context not preserved across processes

The namespace is process-local and doesn't cross process boundaries:

```elixir
NamespaceContext.put("tenant_acme")

Task.async(fn ->
  # This is a different process!
  NamespaceContext.get()  # => nil
  
  # Need to set it again
  NamespaceContext.put("tenant_acme")
end)
```

## Demo

Run the interactive demo (works with both adapters):

```bash
# SQLite (default)
mix multidb.reset
iex -S mix

# Or PostgreSQL
DB_ADAPTER=postgres mix multidb.reset
DB_ADAPTER=postgres iex -S mix
```

```elixir
iex> Multidb.NamespaceDemo.run()

# Output shows:
# - Namespace creation
# - Data insertion per namespace
# - Isolation verification
# - Context switching
# - Cleanup
```

## See Also

- [ADR001: Support for Transparent Namespace Isolation](../@meta/@adr/ADR001-support-namespaces.md)
- [Implementation Summary](../@meta/NAMESPACE_IMPLEMENTATION_SUMMARY.md)
- [README](../README.md)
