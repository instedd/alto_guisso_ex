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
      mod: {Guisso, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:coherence, "~> 0.3"},
      {:hackney, "~> 1.0"},
      {:joken, "~> 1.4"},
      {:httpoison, "~> 0.11"},
      {:cachex, "~> 2.1"},
      {:mock, "~> 0.3.1", only: :test},
      {:postgrex, ">= 0.0.0", only: :test},
      {:junit_formatter, "~> 2.0", only: :test}
    ]
  end
end
