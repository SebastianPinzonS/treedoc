defmodule TreeDocFirmware.ConfigTest do
  use ExUnit.Case, async: false

  @variables ~w(TREEDOC_WIFI_SSID TREEDOC_WIFI_PSK TREEDOC_SSH_KEYS)
  @target Path.expand("../config/target.exs", __DIR__)

  setup do
    previous = Map.new(@variables, &{&1, System.get_env(&1)})

    key_file =
      Path.join(System.tmp_dir!(), "tree-doc-public-key-#{System.unique_integer([:positive])}")

    File.write!(key_file, "# Test fixture, not a usable key\nssh-ed25519 AAAATEST fixture\n")
    System.put_env("TREEDOC_WIFI_SSID", "test-router")
    System.put_env("TREEDOC_WIFI_PSK", "test-password")
    System.put_env("TREEDOC_SSH_KEYS", key_file)

    on_exit(fn ->
      File.rm!(key_file)

      for {name, value} <- previous do
        if value, do: System.put_env(name, value), else: System.delete_env(name)
      end
    end)

    :ok
  end

  test "target config supplies Wi-Fi, SSH and laboratory ports while retaining generated defaults" do
    config = Config.Reader.read!(@target)
    interfaces = Map.new(config[:vintage_net][:config])
    wifi = interfaces["wlan0"]
    assert wifi.ipv4 == %{method: :dhcp}

    assert wifi.vintage_net_wifi.networks == [
             %{key_mgmt: :wpa_psk, ssid: "test-router", psk: "test-password"}
           ]

    assert config[:nerves_ssh][:authorized_keys] == ["ssh-ed25519 AAAATEST fixture"]
    assert config[:kernel][:inet_dist_listen_min] == 4218
    assert config[:kernel][:inet_dist_listen_max] == 4228
    refute Keyword.has_key?(config[:kernel], :net_ticktime)
    assert config[:mdns_lite][:hosts] == [:hostname]
    assert config[:nerves_runtime][:startup_guard_enabled]
    assert interfaces["usb0"].type == VintageNetDirect
  end

  test "missing Wi-Fi credentials fail before building a silently unconfigured image" do
    System.delete_env("TREEDOC_WIFI_PSK")

    assert_raise RuntimeError, ~r/Missing TREEDOC_WIFI_PSK/, fn ->
      Config.Reader.read!(@target)
    end
  end
end
