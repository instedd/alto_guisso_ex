defmodule GuissoTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  test "enabled must be true" do
    assert Guisso.enabled? == true
  end

  test "sign out" do
    conn = build_conn() |> Guisso.sign_out("/redirect")
    assert redirected_to(conn) == "https://alto.guisso/users/sign_out?#{URI.encode_query(after_sign_out_url: "/redirect")}"
  end
end
