# This behaviour only exists so we can mock Guisso during tests.
defmodule Guisso.Client do
  @callback enabled?() :: Bool.t()
  @callback cookie_name :: String.t()
  @callback sign_out(conn :: Plug.Conn.t(), redirect_url :: String.t()) :: Plug.Conn.t()
  @callback sign_up(conn :: Plug.Conn.t(), redirect_url :: String.t()) :: Plug.Conn.t()
  @callback request_auth_code(conn :: Plug.Conn.t(), redirect_url :: String.t()) :: Plug.Conn.t()
  @callback authorize_url(conn :: Plug.Conn.t()) :: Plug.Conn.t()
  @callback request_auth_token(conn :: Plug.Conn.t(), _ :: map()) :: {:ok, String.t(), String.t(), String.t()} | {:error, term()}
  @callback sign_csrf_token(conn :: Plug.Conn.t(), client_id :: String.t(), expiration :: term()) :: String.t()
  @callback verify_csrf_token(conn :: Plug.Conn.t(), state :: String.t()) :: :ok | {:error, String.t()}
end

defmodule Guisso do
  use Application

  @behaviour Guisso.Client

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Guisso.TokenServer, [])
    ]
    opts = [strategy: :one_for_one, name: Guisso.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def enabled? do
    Application.get_env(:alto_guisso, :enabled) == true
  end

  def cookie_name do
    Application.get_env(:alto_guisso, :cookie_name) || "guisso"
  end

  def sign_out(conn, redirect_url) do
    base_url = Application.get_env(:alto_guisso, :base_url)
    sign_out_url = "#{base_url}/users/sign_out?#{URI.encode_query(after_sign_out_url: redirect_url)}"
    Phoenix.Controller.redirect(conn, external: sign_out_url)
  end

  def sign_up(conn, redirect_url) do
    conn = set_client_state(conn, redirect_url)
    base_url = Application.get_env(:alto_guisso, :base_url)
    sign_up_url = "#{base_url}/users/sign_up?#{URI.encode_query(redirect_url: authorize_url(conn))}"
    Phoenix.Controller.redirect(conn, external: sign_up_url)
  end

  def request_auth_code(conn, redirect_url) do
    conn = set_client_state(conn, redirect_url)
    Phoenix.Controller.redirect(conn, external: authorize_url(conn))
  end

  def authorize_url(conn) do
    client_id = Application.get_env(:alto_guisso, :client_id)
    base_url = Application.get_env(:alto_guisso, :base_url)
    auth_url = "#{base_url}/oauth2/authorize"
    csrf_token = generate_csrf_token(conn)

    auth_params = %{
      client_id: client_id,
      response_type: "code",
      scope: "openid email",
      redirect_uri: redirect_uri(conn),
      state: csrf_token,
    }

    "#{auth_url}?#{URI.encode_query(auth_params)}"
  end

  def request_auth_token(conn, %{"code" => code, "state" => state}) do
    client_id = Application.get_env(:alto_guisso, :client_id)
    client_secret = Application.get_env(:alto_guisso, :client_secret)
    base_url = Application.get_env(:alto_guisso, :base_url)
    token_url = "#{base_url}/oauth2/token"
    client_state = get_client_state(conn)

    case verify_csrf_token(conn, state) do
      :ok ->
        token_params = [
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri(conn),
          grant_type: "authorization_code"
        ]

        case :hackney.post(token_url, [], {:form, token_params}) do
          {:ok, 200, _, response_ref} ->
            {:ok, response_body} = :hackney.body(response_ref)
            {:ok, %{ "id_token" => id_token }} = Jason.decode(response_body)
            {:ok, claims} = verify_jwt(id_token, client_secret)

            {:ok, claims["email"], claims["name"], client_state[:redirect]}

          _error ->
            :error
        end
      { :error, _cause } ->
        :error
    end
  end

  defp redirect_uri(conn) do
    Coherence.Controller.router_helpers.session_url(conn, :oauth_callback)
  end

  defp get_client_state(conn) do
    Plug.Conn.get_session(conn, :client_state)
  end

  defp set_client_state(conn, redirect) do
    client_id = :crypto.strong_rand_bytes(10) |> Base.encode64()

    Plug.Conn.put_session(conn, :client_state, %{ client_id: client_id,
                                                  redirect: redirect })
  end

  defp generate_csrf_token(conn) do
    %{client_id: client_id} = get_client_state(conn)
    expiration = :os.system_time(:seconds) + 60 * 5
    signature = sign_csrf_token(conn, client_id, expiration)

    "#{client_id}///#{expiration}///#{signature}"
  end

  def sign_csrf_token(conn, client_id, expiration) do
    data = "#{client_id}///#{expiration}"

    :crypto.hmac(:sha256, conn.secret_key_base, data) |> Base.encode64()
  end

  def verify_csrf_token(conn, state) do
    current_time = :os.system_time(:seconds)
    %{client_id: expected_client_id} = get_client_state(conn)

    case String.split(state, "///") do
      [^expected_client_id, expiration, signature] ->
        case String.to_integer(expiration) do
          num when num > current_time ->
            case sign_csrf_token(conn, expected_client_id, expiration) do
              ^signature ->
                :ok
              _ ->
                {:error, :signature}
            end
          _ ->
            {:error, :expired}
        end
      _ ->
        {:error, :invalid_client}
    end
  end

  defp verify_jwt(id_token, client_secret) do
    token = Joken.token(id_token)

    sign_fn = case Joken.peek_header(token) do
                %{ "alg" => "HS256" } -> &Joken.hs256/1
                %{ "alg" => "HS384" } -> &Joken.hs384/1
                %{ "alg" => "HS512" } -> &Joken.hs512/1
              end

    signer = sign_fn.(client_secret)

    case Joken.verify!(token, signer) do
      {:ok, token} -> {:ok, token}
      {:error, _error} -> :error
    end
  end

end
