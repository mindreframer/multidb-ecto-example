#!/bin/bash

set -e

echo "=========================================="
echo "Running Tests Against All Databases"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to run tests
run_tests() {
  local adapter=$1
  local name=$2
  
  echo -e "${BLUE}=========================================="
  echo "Testing with $name"
  echo -e "==========================================${NC}"
  echo ""
  
  export DB_ADAPTER=$adapter
  
  if MIX_ENV=test mix test; then
    echo -e "${GREEN}✓ $name tests PASSED${NC}"
    echo ""
    return 0
  else
    echo -e "${RED}✗ $name tests FAILED${NC}"
    echo ""
    return 1
  fi
}

# Track results
FAILED=0

# Clean up old SQLite test database
rm -f data/multidb_test.db*

# Test with SQLite (file-based)
echo "Using file-based SQLite for tests..."
if ! run_tests "sqlite" "SQLite (file-based)"; then
  FAILED=$((FAILED + 1))
fi

# Clean up SQLite test database
rm -f data/multidb_test.db*

# Test with PostgreSQL (if available)
echo "Checking if PostgreSQL is available..."
if command -v psql &> /dev/null && psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw template1; then
  echo "PostgreSQL is available, running tests..."
  
  # Create test database if it doesn't exist
  export DB_ADAPTER=postgres
  export DB_NAME=multidb_test
  
  # Try to create the database (ignore error if it exists)
  createdb -U postgres multidb_test 2>/dev/null || true
  
  # Drop and recreate to ensure clean state
  echo "Resetting PostgreSQL test database..."
  dropdb -U postgres --if-exists multidb_test
  createdb -U postgres multidb_test
  
  # Run migrations
  echo "Running migrations..."
  MIX_ENV=test mix multidb.migrate
  
  if ! run_tests "postgres" "PostgreSQL"; then
    FAILED=$((FAILED + 1))
  fi
  
  # Cleanup
  echo "Cleaning up PostgreSQL test database..."
  dropdb -U postgres --if-exists multidb_test
else
  echo -e "${BLUE}PostgreSQL not available or not running, skipping PostgreSQL tests${NC}"
  echo ""
fi

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed! ✓${NC}"
  exit 0
else
  echo -e "${RED}$FAILED test suite(s) failed ✗${NC}"
  exit 1
fi
