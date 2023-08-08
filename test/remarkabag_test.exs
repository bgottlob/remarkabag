defmodule RemarkabagTest do
  use ExUnit.Case
  doctest Remarkabag

  test "greets the world" do
    assert Remarkabag.hello() == :world
  end
end
