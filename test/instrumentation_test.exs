defmodule InstrumentationTest do
  use ExUnit.Case
  import Instrumentation

  test "it works" do
    me = self()

    subscribe "basic", fn payload ->
      send(me, {"basic", payload})
    end

    value = instrument "basic", fn ->
      {"value", []}
    end

    assert value == "value"
    assert_received {"basic", payload}
    assert %{duration: _, tag: nil} = payload
  end

  test "with a tag" do
    me = self()

    # Shouldn't match because instrument is called with atom.
    subscribe "ns", "foo", fn payload ->
      send(me, payload)
    end

    # Shouldn't match because instrument is called with atom.
    subscribe "ns", ~r/fo/, fn payload ->
      send(me, payload)
    end

    subscribe "ns", :foo, fn payload ->
      send(me, payload)
    end

    instrument("ns", :foo, fn -> {nil, []} end)

    assert_received %{duration: _, tag: :foo}
    refute_received %{duration: _, tag: "foo"}
  end

  test "tagged subscriptions don't match untagged instrumentations" do
    me = self()

    subscribe "ns", "foo", fn payload ->
      send(me, payload)
    end

    instrument("ns", fn -> {nil, []} end)

    refute_received %{}
  end

  test "subscribe to all tags" do
    me = self()

    subscribe "ns", fn payload ->
      send(me, payload)
    end

    instrument("ns", "foo", fn -> {nil, []} end)
    instrument("ns", "bar", fn -> {nil, []} end)

    assert_received %{duration: _, tag: "foo"}
    assert_received %{duration: _, tag: "bar"}
  end

  test "doesn't include tag in the payload when subscribe arity is 2" do
    me = self()

    subscribe "ns", fn "foo", payload ->
      send(me, payload)
    end

    instrument("ns", "foo", fn -> {nil, []} end)

    assert_received %{duration: _}
  end

  test "simple timing" do
    me = self()

    subscribe "timing", fn _, payload ->
      send(me, payload)
    end

    assert time("timing", fn -> 123 end) == 123
    assert_received %{duration: _}
  end

end
