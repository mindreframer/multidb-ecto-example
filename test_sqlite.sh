#!/bin/bash

echo "=========================================="
echo "Running Tests with SQLite (file-based)"
echo "=========================================="
echo ""

export DB_ADAPTER=sqlite

# Clean up old test database
rm -f multidb_test.db*

MIX_ENV=test mix test "$@"
