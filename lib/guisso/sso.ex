defmodule Guisso.SSO do
  use Coherence.Config

  defmodule Config do
    defstruct [:enabled, :cookie_name, :session_controller]
  end

  def init(opts) do
    %Config{
      enabled: Guisso.enabled?,
      cookie_name: Guisso.cookie_name,
      session_controller: opts[:session_controller] || Coherence.SessionController
    }
  end

  def call(conn, %Config{enabled: false}) do
    conn
  end

  def call(conn, %Config{cookie_name: cookie_name} = config) do
    guisso_user = conn.cookies[cookie_name] |> URI.decode_www_form
    current_user = case Coherence.current_user(conn) do
      nil -> nil
      user -> user.email
    end

    sso(conn, guisso_user, current_user, config)
  end

  def sso(conn, nil, _, _), do: conn
  def sso(conn, "logout", nil, _), do: conn

  def sso(conn, "logout", _, config) do
    apply(config.session_controller, :delete, [conn, %{}])
  end

  def sso(conn, guisso_user, current_user, _) do
    if guisso_user == current_user do
      conn
    else
      conn
        |> Guisso.request_auth_code("/")
        |> Plug.Conn.halt
    end
  end


end
