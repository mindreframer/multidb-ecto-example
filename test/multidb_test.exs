defmodule MultidbTest do
  use ExUnit.Case
  doctest Multidb

  test "greets the world" do
    assert Multidb.hello() == :world
  end
end
