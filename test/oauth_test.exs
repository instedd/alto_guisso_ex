defmodule OAuthTest do
  use Guisso.Test.ConnCase
  import Mock

  setup do
    user = Guisso.Test.User.insert("foo@bar.com")
    {:ok, [user: user]}
  end

  test "set the current user", %{user: user} do
    token = %{"token_type" => "bearer", "user" => "foo@bar.com"}
    with_mock Guisso.TokenServer, [get_token: fn("1234567890") -> {:ok, token} end] do
      conn = build_conn(:get, "/bar")
        |> put_req_header("authorization", "Bearer 1234567890")
        |> Guisso.OAuth.call(:config)

      assert conn.assigns[:current_user].id == user.id
    end
  end

  test "ignore the token if the type is invalid" do
    token = %{"token_type" => "mac", "user" => "foo@bar.com"}
    with_mock Guisso.TokenServer, [get_token: fn("1234567890") -> {:ok, token} end] do
      conn = build_conn(:get, "/bar")
        |> put_req_header("authorization", "Bearer 1234567890")
        |> Guisso.OAuth.call(:config)

      refute conn.assigns[:current_user]
    end
  end
end
