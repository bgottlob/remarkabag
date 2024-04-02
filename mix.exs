defmodule Remarkabag.MixProject do
  use Mix.Project

  def project do
    [
      app: :remarkabag,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Remarkabag, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:chromic_pdf, "~> 1.12"},
      {:cookie, "~> 0.1"},
      {:elixir_uuid, "~> 1.2"},
      {:jason, "~> 1.4"},
      {:multipart, "~> 0.4"},
      {:oauth2, "~> 2.0"},
      {:req, "~> 0.4"}
    ]
  end
end
