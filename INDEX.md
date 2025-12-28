# Documentation Index

Welcome to the Multidb project! This index will help you find the right documentation for your needs.

## 🚀 Getting Started

**New to this project?** Start here:

1. **[README.md](README.md)** - Project overview and quick introduction
2. **[QUICKSTART.md](QUICKSTART.md)** - Get up and running in 5 minutes

## 📖 User Documentation

**Want to use this in your project?**

- **[README_MULTIDB.md](README_MULTIDB.md)** - Complete user guide
  - Installation
  - Usage examples
  - Configuration
  - Production deployment
  - Code examples

## 🧪 Testing

**Want to run or write tests?**

- **[TESTING.md](TESTING.md)** - Comprehensive testing guide
  - Running tests with SQLite
  - Running tests with PostgreSQL
  - CI/CD setup
  - Troubleshooting
  - Writing tests

## 🏗️ Architecture & Design

**Want to understand how it works?**

- **[SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md)** - Deep dive into the solution
  - Problem statement
  - Architecture overview
  - Design decisions
  - Trade-offs
  - Alternatives
  - Performance considerations

## 📁 File Structure Reference

```
Documentation:
├── README.md                    # Main README
├── INDEX.md                     # This file
├── QUICKSTART.md               # Quick start guide
├── README_MULTIDB.md           # Complete user guide
├── TESTING.md                  # Testing guide
└── SOLUTION_SUMMARY.md         # Architecture deep dive

Scripts:
├── test_sqlite.sh              # Test with SQLite
├── test_all_databases.sh       # Test all databases
├── demo_sqlite.sh              # Demo with SQLite
└── demo_postgres.sh            # Demo with PostgreSQL

Source Code:
lib/
├── multidb/
│   ├── application.ex          # App supervisor
│   ├── repo.ex                 # Dynamic repo facade
│   ├── repos/
│   │   ├── sqlite_repo.ex      # SQLite adapter
│   │   └── postgres_repo.ex    # PostgreSQL adapter
│   ├── schemas/
│   │   └── user.ex             # Example schema
│   ├── accounts.ex             # Example context
│   └── demo.ex                 # Demo module
├── mix/tasks/
│   ├── multidb.migrate.ex      # Migration task
│   └── multidb.reset.ex        # Reset task
└── multidb.ex                  # Main module

Configuration:
config/
├── config.exs                  # Compile-time config
├── runtime.exs                 # Runtime config ⭐
└── test.exs                    # Test config

Tests:
test/
├── support/
│   └── data_case.ex            # Test case template
├── test_helper.exs             # Test setup
└── multidb_test.exs            # Test suite

Database:
priv/repo/migrations/
└── 20231228000001_create_users.exs
```

## 🎯 Common Tasks

### I want to...

**Run the demo**
```bash
# SQLite
./demo_sqlite.sh

# PostgreSQL  
./demo_postgres.sh
```
→ See [QUICKSTART.md](QUICKSTART.md)

**Run tests**
```bash
./test_all_databases.sh
```
→ See [TESTING.md](TESTING.md)

**Use this in my project**
→ See [README_MULTIDB.md](README_MULTIDB.md) - Usage section

**Understand the architecture**
→ See [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md)

**Deploy to production**
→ See [README_MULTIDB.md](README_MULTIDB.md) - Production section

**Write tests**
→ See [TESTING.md](TESTING.md) - Writing Tests section

**Switch databases at runtime**
```bash
DB_ADAPTER=postgres iex -S mix
```
→ See [README.md](README.md) - Configuration section

## 📊 Documentation by Role

### Developer (Using This Pattern)

Priority reading order:
1. [README.md](README.md) - Overview
2. [QUICKSTART.md](QUICKSTART.md) - Get started
3. [README_MULTIDB.md](README_MULTIDB.md) - Complete guide
4. [TESTING.md](TESTING.md) - Testing

### Architect (Evaluating This Solution)

Priority reading order:
1. [README.md](README.md) - Overview
2. [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) - Architecture
3. [README_MULTIDB.md](README_MULTIDB.md) - Implementation details

### DevOps (Deploying This)

Priority reading order:
1. [README.md](README.md) - Overview
2. [README_MULTIDB.md](README_MULTIDB.md) - Production section
3. [TESTING.md](TESTING.md) - CI/CD section

### Curious Developer (Learning)

Priority reading order:
1. [README.md](README.md) - What is this?
2. [QUICKSTART.md](QUICKSTART.md) - Try it out
3. [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) - How does it work?
4. [Source code](lib/multidb/) - Read the implementation

## 💡 Key Concepts

### Runtime Configuration
How environment variables control database selection at startup.
→ [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) - Architecture section

### Facade Pattern
How the `Multidb.Repo` module delegates to the active database.
→ [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.MD) - Design Decisions section

### Testing Strategy
How to test code against multiple databases.
→ [TESTING.md](TESTING.md)

### Production Deployment
How to deploy with runtime database selection.
→ [README_MULTIDB.md](README_MULTIDB.md) - Production section

## 🔗 External Resources

- [Elixir Language](https://elixir-lang.org/)
- [Ecto Documentation](https://hexdocs.pm/ecto)
- [Ecto SQL](https://hexdocs.pm/ecto_sql)
- [Runtime Configuration](https://hexdocs.pm/mix/Mix.Config.html#module-runtime-configuration)
- [Mix Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)

## ❓ FAQ

**Q: Can I use this pattern in production?**  
A: Yes! See [README_MULTIDB.md](README_MULTIDB.md) - Production section

**Q: What's the performance overhead?**  
A: ~100 nanoseconds per call. See [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) - Performance section

**Q: Can I add more database adapters?**  
A: Yes! Just add another repo module. See [README_MULTIDB.md](README_MULTIDB.md)

**Q: Why not use in-memory SQLite for tests?**  
A: Connection pool issues. See [TESTING.md](TESTING.md) - SQLite In-Memory section

**Q: How do I run tests?**  
A: `./test_all_databases.sh` - See [TESTING.md](TESTING.md)

## 🆘 Getting Help

1. Check the appropriate documentation above
2. Run `./test_all_databases.sh` to verify your setup
3. Review the example code in `lib/multidb/demo.ex`
4. Check troubleshooting sections in [TESTING.md](TESTING.md)

## 📝 Document Summaries

| Document | Purpose | Audience | Length |
|----------|---------|----------|--------|
| [README.md](README.md) | Project overview | Everyone | ~300 lines |
| [QUICKSTART.md](QUICKSTART.md) | Get started quickly | New users | ~200 lines |
| [README_MULTIDB.md](README_MULTIDB.md) | Complete user guide | Users | ~400 lines |
| [TESTING.md](TESTING.md) | Testing guide | Developers/DevOps | ~300 lines |
| [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) | Architecture deep dive | Architects | ~400 lines |
| [INDEX.md](INDEX.md) | This file | Everyone | ~200 lines |

## ✅ Checklist for New Users

- [ ] Read [README.md](README.md)
- [ ] Follow [QUICKSTART.md](QUICKSTART.md)
- [ ] Run `./test_sqlite.sh` successfully
- [ ] Run demo with both databases
- [ ] Read [README_MULTIDB.md](README_MULTIDB.md) usage section
- [ ] Understand [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) architecture
- [ ] Ready to build! 🚀

---

**Navigate:** [README](README.md) | [Quickstart](QUICKSTART.md) | [User Guide](README_MULTIDB.md) | [Testing](TESTING.md) | [Architecture](SOLUTION_SUMMARY.md)
