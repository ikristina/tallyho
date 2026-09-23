defmodule TallyHoWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TallyHoWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint TallyHoWeb.Endpoint

      use TallyHoWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TallyHoWeb.ConnCase
    end
  end

  setup tags do
    TallyHo.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Adds the ingest API's Authorization: Bearer header, using the configured test key."
  def with_api_key(conn) do
    api_key = Application.fetch_env!(:tallyho, :ingest_api_key)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> api_key)
  end

  @doc "Adds the dashboard's HTTP Basic Auth header, using the configured test credentials."
  def with_dashboard_auth(conn) do
    [username: username, password: password] = Application.fetch_env!(:tallyho, :dashboard_auth)
    token = Base.encode64("#{username}:#{password}")
    Plug.Conn.put_req_header(conn, "authorization", "Basic " <> token)
  end
end
