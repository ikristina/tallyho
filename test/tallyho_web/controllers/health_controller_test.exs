defmodule TallyHoWeb.HealthControllerTest do
  use TallyHoWeb.ConnCase, async: true

  test "GET /api/health returns ok with no authentication required", %{conn: conn} do
    conn = get(conn, ~p"/api/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
