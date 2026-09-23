defmodule TallyHoWeb.HealthController do
  @moduledoc """
  Unauthenticated health check for Fly.io's `http_service.checks`. Verifies
  the database is actually reachable rather than just "the BEAM process is
  up" — a bare TCP check would report healthy even if Postgres is down.
  """
  use TallyHoWeb, :controller
  alias Ecto.Adapters.SQL

  def show(conn, _params) do
    case SQL.query(TallyHo.Repo, "SELECT 1", []) do
      {:ok, _result} ->
        json(conn, %{status: "ok"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error"})
    end
  end
end
