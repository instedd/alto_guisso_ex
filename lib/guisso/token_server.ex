defmodule Guisso.TokenServer do
  @cache_ref :guisso_token_cache

  def get_token(token_id) do
    case Cachex.get(@cache_ref, token_id) do
      {_, :not_found} -> :not_found
      {_, {:error, reason}} -> {:error, reason}
      {_, token} -> {:ok, token}
    end
  end

  defmodule State do
    defstruct base_url: nil, client_id: nil, client_secret: nil, tokens: %{}
  end

  def start_link do
    state = %State{
      base_url: Application.get_env(:alto_guisso, :base_url),
      client_id: Application.get_env(:alto_guisso, :client_id),
      client_secret: Application.get_env(:alto_guisso, :client_secret)
    }

    opts = [
      fallback: [
        state: state,
        action: &lookup_token/2
      ],
      default_ttl: :timer.minutes(1)
    ]

    Cachex.start_link(@cache_ref, opts)
  end

  defp lookup_token(token_id, state) do
    params = [
      identifier: state.client_id,
      secret: state.client_secret,
      token: token_id
    ]
    url = "#{state.base_url}/oauth2/trusted_token?#{URI.encode_query(params)}"

    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, token} = Poison.decode(body)
        {:commit, token}

      {:ok, %{status_code: 403}} ->
        {:ignore, :not_found}

      {:ok, %{status_code: status_code}} ->
        {:ignore, {:error, {:status_code, status_code}}}

      {:error, %{reason: reason}} ->
        {:ignore, {:error, reason}}
    end
  end

end
