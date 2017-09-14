defmodule AltoGuisso.Mixfile do
  use Mix.Project

  def project do
    [
      app: :alto_guisso,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hackney, "~> 1.0"},
      {:joken, "~> 1.4.1"}
    ]
  end
end
