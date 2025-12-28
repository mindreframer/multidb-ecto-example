#!/bin/bash
set -e

echo "=========================================="
echo "Running Tests Against All Databases"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

run_tests() {
  local adapter=$1
  local name=$2
  local exclude_tag=$3
  
  echo -e "${BLUE}Testing with $name...${NC}"
  export DB_ADAPTER=$adapter
  
  local test_cmd="MIX_ENV=test mix test"
  if [ -n "$exclude_tag" ]; then
    test_cmd="$test_cmd --exclude $exclude_tag"
  fi
  
  if eval "$test_cmd"; then
    echo -e "${GREEN}✓ $name tests PASSED${NC}\n"
    return 0
  else
    echo -e "${RED}✗ $name tests FAILED${NC}\n"
    return 1
  fi
}

FAILED=0

# Clean up old test databases
rm -f data/multidb_test.db*

# Test with SQLite
if ! run_tests "sqlite" "SQLite" "postgres"; then
  FAILED=$((FAILED + 1))
fi

# Test with PostgreSQL (if available)
if command -v psql &> /dev/null && psql -U postgres -lqt 2>/dev/null | grep -qw template1; then
  export DB_ADAPTER=postgres
  
  echo "Resetting PostgreSQL test database..."
  dropdb -U postgres --if-exists multidb_test 2>&1 | grep -v "NOTICE" || true
  createdb -U postgres multidb_test 2>&1 | grep -v "NOTICE" || true
  
  # Run migrations on test database
  echo "Running migrations..."
  DB_ADAPTER=postgres MIX_ENV=test mix multidb.migrate 2>&1 | grep -E "(Running|Migrated|completed)" || true
  
  if ! run_tests "postgres" "PostgreSQL" "sqlite"; then
    FAILED=$((FAILED + 1))
  fi
  
  # Clean up
  dropdb -U postgres --if-exists multidb_test 2>&1 | grep -v "NOTICE" || true
else
  echo -e "${BLUE}PostgreSQL not available, skipping${NC}\n"
fi

# Summary
echo "=========================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed! ✓${NC}"
  exit 0
else
  echo -e "${RED}$FAILED test suite(s) failed ✗${NC}"
  exit 1
fi
