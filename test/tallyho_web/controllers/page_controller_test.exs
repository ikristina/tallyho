defmodule TallyHoWeb.PageControllerTest do
  use TallyHoWeb.ConnCase

  test "GET / redirects to the dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/dashboard/cust_123"
  end
end
