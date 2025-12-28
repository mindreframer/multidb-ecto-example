#!/usr/bin/env elixir

# This script demonstrates the multidb feature
IO.puts("\nStarting Multidb Demo Application...\n")

# The demo will be run via: mix run test_demo.exs
Multidb.Demo.run()

IO.puts("\nDemo Info:")
IO.inspect(Multidb.Demo.info(), pretty: true)
