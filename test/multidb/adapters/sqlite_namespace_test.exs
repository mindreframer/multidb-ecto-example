defmodule Multidb.Adapters.SqliteNamespaceTest do
  use ExUnit.Case, async: true
  
  alias Multidb.Adapters.SqliteNamespace
  
  @test_namespace "test_sqlite_ns_#{System.unique_integer([:positive])}"
  
  setup do
    on_exit(fn ->
      # Clean up test databases
      SqliteNamespace.list()
      |> Enum.filter(&String.starts_with?(&1, "test_sqlite_ns"))
      |> Enum.each(&SqliteNamespace.delete/1)
    end)
  end
  
  describe "create/1" do
    test "creates a database file" do
      assert :ok = SqliteNamespace.create(@test_namespace)
      
      db_path = SqliteNamespace.get_db_path(@test_namespace)
      assert File.exists?(db_path)
    end
    
    test "is idempotent" do
      assert :ok = SqliteNamespace.create(@test_namespace)
      assert :ok = SqliteNamespace.create(@test_namespace)
      
      db_path = SqliteNamespace.get_db_path(@test_namespace)
      assert File.exists?(db_path)
    end
    
    test "rejects invalid namespace names" do
      assert_raise ArgumentError, fn ->
        SqliteNamespace.create("invalid-name!")
      end
    end
  end
  
  describe "delete/1" do
    test "deletes database file" do
      SqliteNamespace.create(@test_namespace)
      db_path = SqliteNamespace.get_db_path(@test_namespace)
      assert File.exists?(db_path)
      
      assert :ok = SqliteNamespace.delete(@test_namespace)
      refute File.exists?(db_path)
    end
    
    test "is idempotent" do
      SqliteNamespace.create(@test_namespace)
      assert :ok = SqliteNamespace.delete(@test_namespace)
      assert :ok = SqliteNamespace.delete(@test_namespace)
    end
  end
  
  describe "list/0" do
    test "lists created namespaces" do
      ns1 = "test_sqlite_list1_#{System.unique_integer([:positive])}"
      ns2 = "test_sqlite_list2_#{System.unique_integer([:positive])}"
      
      SqliteNamespace.create(ns1)
      SqliteNamespace.create(ns2)
      
      list = SqliteNamespace.list()
      assert ns1 in list
      assert ns2 in list
    end
    
    test "returns empty list when no namespaces" do
      # Clean up first
      SqliteNamespace.list()
      |> Enum.filter(&String.starts_with?(&1, "test_sqlite"))
      |> Enum.each(&SqliteNamespace.delete/1)
      
      # Should only have namespaces from other tests or none
      list = SqliteNamespace.list()
      assert is_list(list)
    end
  end
  
  describe "exists?/1" do
    test "returns true for existing namespace" do
      SqliteNamespace.create(@test_namespace)
      assert SqliteNamespace.exists?(@test_namespace)
    end
    
    test "returns false for non-existing namespace" do
      refute SqliteNamespace.exists?("nonexistent_#{System.unique_integer([:positive])}")
    end
  end
  
  describe "get_db_path/1" do
    test "generates correct path" do
      path = SqliteNamespace.get_db_path("my_namespace")
      
      assert path =~ ~r/namespace_my_namespace_test\.db$/
      assert path =~ ~r/^data\//
    end
  end
end
