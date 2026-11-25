defmodule TreeDoc.WebTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn
  alias TreeDoc.{Replica, Web}

  setup do
    replica = start_supervised!({Replica, name: :web_test, me: :web_author, path: nil})
    %{replica: replica}
  end

  defp request(replica, method, path, body \\ nil) do
    conn(method, path, if(body, do: Jason.encode!(body)))
    |> put_req_header("content-type", "application/json")
    |> put_private(:tree_doc_replica, replica)
    |> Web.call(Web.init([]))
  end

  defp read(replica, path \\ "/state") do
    response = request(replica, :get, path)
    assert response.status == 200
    Jason.decode!(response.resp_body)
  end

  defp change(text, seq \\ 0, anchor \\ [], ids \\ []),
    do: %{del: ids, after: anchor, ins: text, seq: seq}

  test "serves the editor and a consistent snapshot", %{replica: r} do
    page = request(r, :get, "/")
    assert page.status == 200
    assert page.resp_body =~ "Shared document"
    assert read(r)["chars"] == []
    assert request(r, :post, "/edit", change("a👩‍💻é\n")).status == 200
    st = read(r)
    assert Enum.map_join(st["chars"], & &1["ch"]) == "a👩‍💻é\n"
    assert st["seq"] == st["history"]
    assert st["seq"] == 4
  end

  test "rejects duplicate retries and concurrent tabs without repeating insertions", %{replica: r} do
    assert request(r, :post, "/edit", change("once")).status == 200
    assert request(r, :post, "/edit", change("once")).status == 409
    assert request(r, :post, "/edit", change("other tab")).status == 409
    assert GenServer.call(r, :text) == "once"
    assert read(r)["seq"] == 4
  end

  test "HTTP edits coexist with remote operations and stale deleted anchors", %{replica: r} do
    assert request(r, :post, "/edit", change("ab")).status == 200
    [a, b] = read(r)["chars"]
    core = GenServer.call(r, :state)
    [{anchor, _}, {deleted, _}] = TreeDoc.Document.visible(core.doc)
    remote = %{op: :del, pos: deleted, from: :remote_web, vc: %{web_author: 2, remote_web: 1}}
    GenServer.cast(r, {:remote, remote})
    assert GenServer.call(r, :text) == "a"
    assert request(r, :post, "/edit", change("X", 2, b["id"])).status == 200
    assert GenServer.call(r, :text) == "aX"
    assert request(r, :post, "/edit", change("Y", 3, a["id"], [a["id"]])).status == 200
    assert GenServer.call(r, :text) == "YX"
    assert MapSet.member?(GenServer.call(r, :state).doc.tombstones, anchor)
  end

  test "two HTTP clients on separate replicas converge after concurrent edits", %{replica: a} do
    b = start_supervised!({Replica, name: :web_peer, me: :web_peer, path: nil}, id: :peer)

    tasks =
      for {r, text} <- [{a, "hello"}, {b, "world"}],
          do: Task.async(fn -> request(r, :post, "/edit", change(text)).status end)

    assert Enum.map(tasks, &Task.await/1) == [200, 200]
    ah = GenServer.call(a, :state).history
    bh = GenServer.call(b, :state).history
    for op <- Enum.reverse(ah) ++ ah, do: GenServer.cast(b, {:remote, op})
    for op <- Enum.reverse(bh) ++ bh, do: GenServer.cast(a, {:remote, op})
    assert read(a)["chars"] == read(b)["chars"]
    assert read(a)["clock"] == read(b)["clock"]
    assert read(a)["waiting"] == 0
    assert read(b)["waiting"] == 0
  end

  test "rejects malformed and unknown IDs without changing the document", %{replica: r} do
    assert request(r, :post, "/edit", %{ins: "x"}).status == 400

    for id <- [
          [[2, 1, "web_author"]],
          [[1, 99, "web_author"]],
          [[1, 1, "never-created-node-9842"]]
        ] do
      assert request(r, :post, "/edit", change("x", 0, id)).status == 422
    end

    assert read(r)["history"] == 0
    assert request(r, :get, "/api/doc?node=never-created-node-9842").status == 404
    assert request(r, :get, "/missing").status == 404
  end

  test "read-only tabs expose real state, history, and tombstones", %{replica: r} do
    assert request(r, :post, "/edit", change("ab")).status == 200
    [a, _] = read(r)["chars"]
    assert request(r, :post, "/edit", change("", 2, [], [a["id"]])).status == 200
    assert read(r, "/api/doc")["text"] == "b"
    assert read(r, "/api/status")["status"]["dead"] == 1
    assert read(r, "/api/raw")["total"] == 2
    assert read(r, "/api/ops")["total"] == 3
    assert hd(read(r, "/api/peers")["rows"])["same_text"]
  end

  test "disk failure rejects the complete HTTP edit", %{replica: _} do
    dir = Path.join(System.tmp_dir!(), "web-io-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(dir) end)

    r =
      start_supervised!({Replica, name: :web_io, me: :web_io, path: Path.join(dir, "history")},
        id: :io
      )

    File.write!(dir, "blocks directory creation")
    assert request(r, :post, "/edit", change("unsaved")).status == 422
    assert read(r)["chars"] == []
    assert read(r)["seq"] == 0
  end

  test "an unavailable replica produces a retryable HTTP error" do
    assert request(:missing_web_replica, :get, "/state").status == 503
    assert request(:missing_web_replica, :post, "/edit", change("draft")).status == 503
  end
end
