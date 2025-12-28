#!/bin/bash

echo "========================================"
echo "Demo: Multidb with SQLite"
echo "========================================"
echo ""

# Reset and migrate the database
echo "1. Resetting database..."
mix multidb.reset

echo ""
echo "2. Starting IEx session with SQLite..."
echo "   Run: Multidb.Demo.run()"
echo ""

iex -S mix
