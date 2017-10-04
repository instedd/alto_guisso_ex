defmodule Guisso.OAuth do
  import Plug.Conn
  import Ecto.Query

  def init(_opts) do
  end

  def call(conn, _config) do
    with {:ok, token_type, token_id} <- find_token_id(conn),
         {:ok, conn, token} <- find_token(conn, token_type, token_id),
         {:ok, conn} <- validate_scope(conn, token),
         {:ok, conn} <- authenticate(conn, token)
    do
      conn
    else
      {:cancel, conn} -> conn
    end
  end

  defp authenticate(conn, %{"user" => login}) do
    user = find_user(login)
    conn = assign(conn, Coherence.Config.assigns_key, user)
    {:ok, conn}
  end

  defp find_user(login) do
    user_schema = Coherence.Config.user_schema
    login_field = Coherence.Config.login_field
    Coherence.Config.repo.one(from u in user_schema, where: field(u, ^login_field) == ^login)
  end

  defp find_token(conn, token_type, token_id) do
    case Guisso.TokenServer.get_token(token_id) do
      {:ok, %{"token_type" => ^token_type} = token} ->
        {:ok, assign(conn, :guisso_token, token), token}

      {:ok, _} ->
        # The token was found but it's not of the right type
        {:cancel, conn}

      :not_found ->
        # The token is invalid
        {:cancel, conn}

      {:error, reason} ->
        raise "Could not get token from Guisso server (reason: #{inspect reason})"
    end
  end

  defp find_token_id(conn) do
    get_header_token(conn) || get_params_token(conn) || {:cancel, conn}
  end

  defp get_header_token(conn) do
    conn
    |> get_req_header("authorization")
    |> find_header_token
  end

  defp find_header_token([]), do: nil
  defp find_header_token([auth_header | other]) do
    case auth_header do
      "Bearer " <> bearer_token -> {:ok, "bearer", bearer_token}
      _ -> find_header_token(other)
    end
  end

  defp get_params_token(conn) do
    case conn.params do
      %{"access_token" => bearer_token} -> {:ok, "bearer", bearer_token}
      _ -> nil
    end
  end

  defp validate_scope(conn, %{"scope" => scope}) do
    scopes = scope |> String.split(" ", trim: true)
    validate_scope_elements(conn, scopes)
  end

  defp validate_scope(conn, _token) do
    {:ok, conn}
  end

  defp validate_scope_elements(conn, []), do: {:ok, conn}

  defp validate_scope_elements(conn, [scope | scopes]) do
    case String.split(scope, "=", parts: 2) do
      [_] -> validate_scope_elements(conn, scopes)
      [key, value] ->
        case validate_scope_element(conn, key, value) do
          {:ok, conn} -> validate_scope_elements(conn, scopes)
          other -> other
        end
    end
  end

  defp validate_scope_element(conn, "url:path", path) do
    if conn.request_path == path do
      {:ok, conn}
    else
      conn = conn
        |> put_status(:forbidden)
        |> halt
      {:cancel, conn}
    end
  end

  defp validate_scope_element(conn, _, _), do: {:ok, conn}
end
