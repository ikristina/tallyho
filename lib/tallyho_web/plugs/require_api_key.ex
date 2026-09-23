defmodule TallyHoWeb.Plugs.RequireApiKey do
  @moduledoc """
  Requires `Authorization: Bearer <key>` on the usage-ingestion API, checked
  against a single shared key (`config :tallyho, :ingest_api_key`).

  A shared key is appropriate for a personal-demo deployment with one
  operator. A real multi-tenant product would issue and validate a key per
  customer instead of a single global secret.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    expected_key = Application.fetch_env!(:tallyho, :ingest_api_key)

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 ->
        if Plug.Crypto.secure_compare(token, expected_key) do
          conn
        else
          unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "missing or invalid API key"})
    |> halt()
  end
end
