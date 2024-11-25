defmodule OffBroadwayMemory.MixProject do
  use Mix.Project

  @version "1.2.0"
  @repo_url "https://github.com/elliotekj/off_broadway_memory"

  def project do
    [
      app: :off_broadway_memory,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:broadway, "~> 1.0"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Elliot Jackson"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp description do
    """
    A Broadway producer for an in-memory buffer.
    """
  end

  defp docs do
    [
      name: "OffBroadwayMemory",
      main: "OffBroadwayMemory.Producer",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/off_broadway_memory",
      source_url: @repo_url
    ]
  end
end
