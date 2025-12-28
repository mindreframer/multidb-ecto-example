defmodule Multidb.NamespaceContextTest do
  use ExUnit.Case, async: true
  
  alias Multidb.NamespaceContext
  
  setup do
    # Clean up after each test
    on_exit(fn -> NamespaceContext.delete() end)
    :ok
  end
  
  describe "put/1 and get/0" do
    test "sets and retrieves namespace" do
      assert NamespaceContext.get() == nil
      
      NamespaceContext.put("tenant_acme")
      assert NamespaceContext.get() == "tenant_acme"
      
      NamespaceContext.put("tenant_globex")
      assert NamespaceContext.get() == "tenant_globex"
    end
  end
  
  describe "delete/0" do
    test "clears the namespace" do
      NamespaceContext.put("tenant_acme")
      assert NamespaceContext.get() == "tenant_acme"
      
      NamespaceContext.delete()
      assert NamespaceContext.get() == nil
    end
  end
  
  describe "with_namespace/2" do
    test "executes function in temporary namespace" do
      NamespaceContext.put("original")
      
      result = NamespaceContext.with_namespace("temporary", fn ->
        assert NamespaceContext.get() == "temporary"
        :ok
      end)
      
      assert result == :ok
      assert NamespaceContext.get() == "original"
    end
    
    test "restores namespace even on error" do
      NamespaceContext.put("original")
      
      assert_raise RuntimeError, fn ->
        NamespaceContext.with_namespace("temporary", fn ->
          raise "error"
        end)
      end
      
      assert NamespaceContext.get() == "original"
    end
    
    test "works when no previous namespace set" do
      assert NamespaceContext.get() == nil
      
      NamespaceContext.with_namespace("temporary", fn ->
        assert NamespaceContext.get() == "temporary"
      end)
      
      assert NamespaceContext.get() == nil
    end
  end
  
  describe "process isolation" do
    test "namespace is isolated per process" do
      NamespaceContext.put("process_1")
      
      task = Task.async(fn ->
        # Different process should not see parent's namespace
        assert NamespaceContext.get() == nil
        NamespaceContext.put("process_2")
        NamespaceContext.get()
      end)
      
      assert Task.await(task) == "process_2"
      assert NamespaceContext.get() == "process_1"
    end
  end
end
