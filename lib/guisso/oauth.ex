defmodule Guisso.OAuth do
  import Plug.Conn
  import Ecto.Query

  def init(_opts) do
  end

  def call(conn, _config) do
    case get_token(conn) do
      nil -> conn
      bearer_token ->
        case authenticate(bearer_token) do
          nil -> conn
          login ->
            user = find_user(login)
            conn
            |> assign(Coherence.Config.assigns_key, user)
        end
    end
  end

  defp find_user(login) do
    user_schema = Coherence.Config.user_schema
    login_field = Coherence.Config.login_field
    Coherence.Config.repo.one(from u in user_schema, where: field(u, ^login_field) == ^login)
  end

  defp authenticate(bearer_token) do
    case Guisso.TokenServer.get_token(bearer_token) do
      {:ok, %{"token_type" => "bearer", "user" => user}} ->
        user

      {:ok, _} ->
        # The token was found but it's not a Bearer token
        nil

      :not_found ->
        # The token is invalid
        nil

      {:error, reason} ->
        raise "Could not get token from Guisso server (reason: #{inspect reason})"
    end
  end

  defp get_token(conn) do
    get_header_token(conn) || get_params_token(conn)
  end

  defp get_header_token(conn) do
    conn
    |> get_req_header("authorization")
    |> find_header_token
  end

  defp find_header_token([]), do: nil
  defp find_header_token([auth_header | other]) do
    case auth_header do
      "Bearer " <> bearer_token -> bearer_token
      _ -> find_header_token(other)
    end
  end

  defp get_params_token(conn) do
    case conn.params do
      %{"access_token" => bearer_token} -> bearer_token
      _ -> nil
    end
  end
end
