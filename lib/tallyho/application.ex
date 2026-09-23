defmodule TallyHo.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TallyHoWeb.Telemetry,
      TallyHo.Repo,
      {DNSCluster, query: Application.get_env(:tallyho, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TallyHo.PubSub},
      # Start a worker by calling: TallyHo.Worker.start_link(arg)
      # {TallyHo.Worker, arg},
      # Start to serve requests, typically the last entry
      TallyHoWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TallyHo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TallyHoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
