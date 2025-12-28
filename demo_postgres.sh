#!/bin/bash

echo "========================================"
echo "Demo: Multidb with PostgreSQL"
echo "========================================"
echo ""

export DB_ADAPTER=postgres

echo "1. Resetting database..."
mix multidb.reset

echo ""
echo "2. Starting IEx session with PostgreSQL..."
echo "   Run: Multidb.Demo.run()"
echo ""

iex -S mix
