# ADR 001: Support for Transparent Namespace Isolation

## Status

Proposed

## Context

We need to add namespace support to the Multidb proof of concept to enable multi-tenant database operations. The system currently supports runtime switching between PostgreSQL and SQLite adapters, and we want to extend this to support multiple isolated namespaces within each adapter.

### Requirements

- Each namespace should provide complete data isolation
- Namespace handling must be transparent to business logic
- Developers should not be able to accidentally use the wrong namespace
- The solution should leverage database-native features where possible
- Must work with both PostgreSQL and SQLite adapters

### Key Constraint

**The namespace context must NOT contaminate the database API.** We explicitly reject approaches that require passing `namespace:` options through every function call, as this:
- Pollutes business logic with infrastructure concerns
- Creates opportunities for human error (forgetting to pass namespace)
- Makes the codebase harder to maintain
- Violates separation of concerns

## Decision

We will implement **process-scoped namespace context** using Elixir's process dictionary, combined with adapter-specific implementations:

### Architecture

#### 1. Process-Scoped Context (`Multidb.NamespaceContext`)

A module that stores the current namespace in the process dictionary, making it automatically available to all database operations in that process without explicit passing.

```elixir
# Set once per process (e.g., at web request start)
Multidb.NamespaceContext.put("tenant_acme")

# All subsequent operations use this namespace automatically
Accounts.create_user(%{name: "Alice", email: "alice@acme.com"})
Accounts.list_users()
```

#### 2. Transparent Repository Layer (`Multidb.Repo`)

The existing facade pattern will be enhanced to:
- Automatically read the namespace from process context
- Resolve the appropriate repo for that namespace
- Apply namespace transformations to queries/changesets
- All without requiring changes to business logic

#### 3. Adapter-Specific Implementations

**PostgreSQL:**
- Uses native PostgreSQL schemas (`CREATE SCHEMA namespace_name`)
- Single connection pool with query-level schema prefix
- Leverages Ecto's built-in `:prefix` option
- Efficient resource usage

**SQLite:**
- Uses separate database files per namespace (`namespace_<name>_<env>.db`)
- Dynamic repo instances managed by `Multidb.NamespaceRegistry`
- Repos started on-demand and cached
- Complete file-level isolation

### Components

```
lib/multidb/
├── namespace_context.ex          # Process dictionary-based context
├── namespace_registry.ex         # SQLite multi-repo management
├── namespace.ex                  # Public API for namespace CRUD
├── adapters/
│   ├── postgres_namespace.ex     # PostgreSQL schema operations
│   └── sqlite_namespace.ex       # SQLite file-based operations
└── repo.ex                       # Enhanced facade with transparent namespace
```

### Flow

```
Web Request → Plug sets namespace → Process Dictionary
                                            ↓
Business Logic → Accounts.create_user() → Repo.insert()
                                            ↓
                        Repo reads namespace from Process Dictionary
                                            ↓
                    ┌──────────────────────┴─────────────────────┐
                    ↓                                             ↓
            PostgreSQL Path                              SQLite Path
                    ↓                                             ↓
        Add schema prefix to query                Get/start namespace-specific repo
                    ↓                                             ↓
        Execute on main connection             Execute on namespace DB file
```

## Consequences

### Positive

✅ **Zero API Pollution** - Business logic remains completely clean, no namespace parameters  
✅ **Type Safety** - Process isolation prevents accidental namespace mixing  
✅ **Developer Experience** - Impossible to forget or misuse namespaces  
✅ **Web-Friendly** - Perfect fit for Phoenix Plugs and request lifecycle  
✅ **Test-Friendly** - Easy to set namespace in test setup blocks  
✅ **Performance** - Process dictionary access is extremely fast  
✅ **Database-Native** - Leverages PostgreSQL schemas and SQLite file isolation  
✅ **Minimal Changes** - Existing business logic code doesn't change  

### Negative

⚠️ **Process-Bound Context** - Namespace context doesn't cross process boundaries (but this is generally desired for isolation)  
⚠️ **SQLite Resource Usage** - Each active namespace requires a separate connection pool  
⚠️ **Implicit Behavior** - Namespace is "magic" and not visible in function signatures (mitigated by clear documentation)  

### Trade-offs

- **Explicit vs Implicit**: We choose implicit namespace handling (process context) over explicit parameter passing to prevent API pollution and human error
- **Single vs Multiple Connections (SQLite)**: We use multiple DB files/repos for complete isolation rather than attempting multi-tenancy in a single SQLite database
- **Eager vs Lazy (SQLite)**: We start namespace repos on-demand to conserve resources

## Implementation Notes

### Phase 1: Core Infrastructure
1. `Multidb.NamespaceContext` - Process dictionary wrapper
2. Enhanced `Multidb.Repo` with automatic namespace resolution
3. `Multidb.NamespaceRegistry` for SQLite repo management
4. Update `Multidb.Application` to start necessary supervisors

### Phase 2: Adapter Implementations
1. `Multidb.Adapters.PostgresNamespace` - Schema management
2. `Multidb.Adapters.SqliteNamespace` - File-based management
3. `Multidb.Namespace` - Unified public API

### Phase 3: Integration
1. Phoenix Plug for web request namespace injection
2. Mix tasks for namespace creation/migration
3. Test helpers for namespace setup

### PostgreSQL Specifics

```sql
-- Create namespace
CREATE SCHEMA IF NOT EXISTS tenant_acme;

-- Set search path (via Ecto prefix)
SELECT * FROM tenant_acme.users;

-- List namespaces
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'public');

-- Delete namespace
DROP SCHEMA IF EXISTS tenant_acme CASCADE;
```

### SQLite Specifics

```
data/
├── namespace_tenant_acme_dev.db
├── namespace_tenant_globex_dev.db
└── namespace_tenant_xyz_dev.db
```

Each file gets its own Ecto.Repo instance, supervised by `DynamicSupervisor`.

## Examples

### Basic Usage

```elixir
# Set namespace for current process
Multidb.NamespaceContext.put("tenant_acme")

# All operations use this namespace automatically
alias Multidb.Accounts

{:ok, user} = Accounts.create_user(%{name: "Alice", email: "alice@acme.com"})
users = Accounts.list_users()
Accounts.update_user(user, %{age: 30})
```

### Temporary Namespace Context

```elixir
Multidb.NamespaceContext.with_namespace("tenant_xyz", fn ->
  # All operations in this block use tenant_xyz
  Accounts.create_user(%{name: "Bob", email: "bob@xyz.com"})
  Accounts.list_users()
end)
# Previous namespace is automatically restored
```

### Phoenix Integration

```elixir
defmodule MultidbWeb.NamespacePlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    namespace = extract_namespace_from_subdomain(conn)
    Multidb.NamespaceContext.put(namespace)
    conn
  end
  
  defp extract_namespace_from_subdomain(conn) do
    case conn.host |> String.split(".") do
      [subdomain | _] -> subdomain
      _ -> "default"
    end
  end
end

# In router
pipeline :browser do
  plug :accepts, ["html"]
  plug MultidbWeb.NamespacePlug  # Set namespace per request
end
```

### Testing

```elixir
defmodule Multidb.AccountsTest do
  use Multidb.DataCase
  
  setup do
    # Set namespace for this test process
    Multidb.NamespaceContext.put("test_tenant_#{System.unique_integer()}")
    :ok
  end
  
  test "creates user in isolated namespace" do
    # No namespace parameter needed - completely transparent!
    {:ok, user} = Accounts.create_user(%{name: "Alice", email: "a@test.com"})
    assert user.name == "Alice"
  end
  
  test "namespace isolation" do
    Multidb.NamespaceContext.put("ns1")
    Accounts.create_user(%{name: "Alice", email: "a@test.com"})
    
    Multidb.NamespaceContext.put("ns2")
    Accounts.create_user(%{name: "Bob", email: "b@test.com"})
    
    # Each namespace has only its own data
    assert length(Accounts.list_users()) == 1
    
    Multidb.NamespaceContext.put("ns1")
    assert length(Accounts.list_users()) == 1
  end
end
```

## Alternatives Considered

### Alternative 1: Explicit Namespace Parameter (Rejected)

```elixir
# Rejected approach - namespace in every call
Accounts.create_user(%{name: "Alice"}, namespace: "tenant_acme")
Accounts.list_users(namespace: "tenant_acme")
```

**Rejected because:**
- Pollutes business logic with infrastructure concerns
- Easy to forget or use wrong namespace
- Verbose and repetitive
- Hard to refactor

### Alternative 2: Configuration-Based (Rejected)

Set namespace globally via Application config.

**Rejected because:**
- Can't handle multiple namespaces in same VM
- Not suitable for web applications serving multiple tenants
- Requires restart to change namespace

### Alternative 3: Separate Application per Namespace (Rejected)

Run entirely separate application instances for each tenant.

**Rejected because:**
- Massive resource overhead
- Complex deployment
- Over-engineering for the use case

## References

- [Ecto Query Prefix Documentation](https://hexdocs.pm/ecto/Ecto.Query.html#module-query-prefix)
- [PostgreSQL Schema Documentation](https://www.postgresql.org/docs/current/ddl-schemas.html)
- [Process Dictionary in Elixir](https://hexdocs.pm/elixir/Process.html#get/2)
- [Ecto.Adapters.SQL.Sandbox](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html) - Similar pattern for test isolation

## Notes

- The process dictionary approach is similar to how `Ecto.Adapters.SQL.Sandbox` manages test isolation
- For production deployments, consider namespace cleanup policies for deleted tenants
- SQLite namespace repos can be stopped when idle to conserve resources (future optimization)
- Migrations need to be run for each PostgreSQL schema or each SQLite database file

---

**Date:** 2024-12-28  
**Authors:** Development Team  
**Decision:** Proposed
