defmodule TallyHoWeb.DashboardLiveTest do
  use TallyHoWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias TallyHo.Usage

  describe "DashboardLive" do
    test "mounts and displays empty state for customer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/cust_test")

      assert has_element?(view, "h1", "Usage & Invoicing Dashboard")
      assert has_element?(view, "#events")
      assert render(view) =~ "$0.00"
    end

    test "switches customer on form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/cust_1")

      view
      |> form("form", %{"customer_id" => "cust_new"})
      |> render_submit()

      assert_patched(view, ~p"/dashboard/cust_new")
    end

    test "updates invoice and prepends to stream when event arrives via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/cust_live")

      assert render(view) =~ "$0.00"

      # Simulate an event arriving from an external API call
      {:ok, event} =
        Usage.ingest_event(%{
          "customer_id" => "cust_live",
          "metric" => "compute_hours",
          "quantity" => 10,
          "idempotency_key" => "live_test_key"
        })

      # LiveView receives the PubSub broadcast and re-renders
      html = render(view)

      # 10 compute_hours * $0.10 = $1.00
      assert html =~ "$1.00"
      assert has_element?(view, "#events-#{event.id}")
      assert html =~ "compute_hours"
    end
  end
end
