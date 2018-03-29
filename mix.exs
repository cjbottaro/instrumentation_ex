defmodule Instrumentation.MixProject do
  use Mix.Project

  def project do
    [
      app: :instrumentation,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Simple instrumentation framework inspired by ActiveSupport::Notifications.",
      package: [
        maintainers: ["Christopher J. Bottaro"],
        licenses: ["GNU General Public License v3.0"],
        links: %{"GitHub" => "https://github.com/cjbottaro/instrumentation_ex"},
      ],

      # Docs
      docs: [
        main: "Instrumentation",
        extras: [
          "README.md": [title: "README"],
          "CHANGELOG.md": [title: "CHANGELOG"]
        ]
      ]

    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Instrumentation.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end
end
