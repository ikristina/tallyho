defmodule TallyHoWeb.PageController do
  use TallyHoWeb, :controller

  # No standalone landing page — the dashboard is the product.
  def home(conn, _params) do
    redirect(conn, to: ~p"/dashboard/cust_123")
  end
end
