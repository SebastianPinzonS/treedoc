defmodule TreeDocFirmware.DiscoveryTest do
  use ExUnit.Case, async: true
  alias TreeDocFirmware.Discovery

  test "laboratory subnet excludes this node, network and broadcast addresses" do
    hosts = Discovery.hosts({192, 168, 1, 20})
    assert length(hosts) == 253
    refute {192, 168, 1, 20} in hosts
    refute {192, 168, 1, 0} in hosts
    refute {192, 168, 1, 255} in hosts
    assert {192, 168, 1, 254} in hosts
  end

  test "finds different names without assuming the doc prefix" do
    assert Discovery.names(
             <<4369::32>> <> "name doc at port 4218\nname nerves-abcd at port 4220\n"
           ) == ["doc", "nerves-abcd"]

    assert Discovery.names("basura") == []
    assert Discovery.names(<<4369::32>> <> "name a@otro at port 4218\n") == []
    assert Discovery.names(<<4369::32>> <> String.duplicate("x", 8193)) == []
  end
end
