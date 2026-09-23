defmodule TallyHoWeb.PageController do
  use TallyHoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
