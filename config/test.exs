import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :tallyho, TallyHo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tallyho_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tallyho, TallyHoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "784EOe6WWIa2VCpYjqDglPsHXtPErPjAoArEy0SvPayljNZTiM4BMi4KhiAgASML",
  server: false

# In test we don't send emails
config :tallyho, TallyHo.Mailer, adapter: Swoosh.Adapters.Test

# Fixed values so tests can construct valid Authorization headers.
config :tallyho,
  ingest_api_key: "test-only-ingest-key",
  dashboard_auth: [username: "test-admin", password: "test-admin"]

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
