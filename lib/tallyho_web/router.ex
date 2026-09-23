defmodule TallyHoWeb.Router do
  use TallyHoWeb, :router

  # 'unsafe-inline' is scoped to style-src only, needed because LiveView
  # sets some inline `style=""` attributes for transitions. script-src has
  # no such carve-out: the one inline <script> we ship (the theme-toggle
  # IIFE in root.html.heex) is allow-listed by its exact sha256 hash
  # instead, so an attacker-injected inline script still can't execute. If
  # that script's contents ever change, recompute the hash with:
  #   sed -n '12,37p' lib/tallyho_web/components/layouts/root.html.heex \
  #     | openssl dgst -sha256 -binary | openssl base64
  @content_security_policy [
                             "default-src 'self'",
                             "script-src 'self' 'sha256-heV471C7/iV0LivI4wLfk+a6YLUgW1OHrFwYFtdTz9k='",
                             "style-src 'self' 'unsafe-inline'",
                             "img-src 'self' data:",
                             "connect-src 'self'",
                             "base-uri 'self'",
                             "frame-ancestors 'self'"
                           ]
                           |> Enum.join("; ")

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TallyHoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @content_security_policy}
  end

  pipeline :dashboard_auth do
    plug :require_dashboard_auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_api_key do
    plug TallyHoWeb.Plugs.RequireApiKey
  end

  scope "/", TallyHoWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Every customer's usage and running invoice would otherwise be visible
  # to anyone who can guess a customer_id — this is a single shared
  # operator credential, not per-customer authorization. A real
  # multi-tenant product would check the logged-in user against the
  # customer_id in the URL instead.
  scope "/", TallyHoWeb do
    pipe_through [:browser, :dashboard_auth]

    live "/dashboard", DashboardLive, :index
    live "/dashboard/:customer_id", DashboardLive, :show
  end

  scope "/api", TallyHoWeb do
    pipe_through :api

    get "/health", HealthController, :show
  end

  scope "/api", TallyHoWeb do
    pipe_through [:api, :require_api_key]

    post "/events", EventController, :create
  end

  defp require_dashboard_auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn, Application.fetch_env!(:tallyho, :dashboard_auth))
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tallyho, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TallyHoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
