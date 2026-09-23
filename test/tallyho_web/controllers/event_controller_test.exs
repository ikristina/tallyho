defmodule TallyHoWeb.EventControllerTest do
  use TallyHoWeb.ConnCase, async: true

  @valid_attrs %{
    "customer_id" => "cust_123",
    "metric" => "api_requests",
    "quantity" => 42,
    "idempotency_key" => "idem_001"
  }

  describe "POST /api/events" do
    test "ingests a valid event and returns 201 Created", %{conn: conn} do
      conn = post(conn, ~p"/api/events", @valid_attrs)

      assert %{"status" => "success", "data" => data} = json_response(conn, 201)
      assert data["customer_id"] == "cust_123"
      assert data["metric"] == "api_requests"
      assert data["quantity"] == 42
      assert data["id"] != nil
    end

    test "rejects duplicate idempotency_key with 409 Conflict", %{conn: conn} do
      conn1 = post(conn, ~p"/api/events", @valid_attrs)
      assert json_response(conn1, 201)

      # Second post with identical idempotency_key
      conn2 = post(conn, ~p"/api/events", @valid_attrs)
      assert %{"error" => msg} = json_response(conn2, 409)
      assert msg =~ "Duplicate idempotency_key"
    end

    test "returns 422 with validation errors for invalid input", %{conn: conn} do
      invalid_attrs = %{"customer_id" => "", "quantity" => -1}
      conn = post(conn, ~p"/api/events", invalid_attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["customer_id"] != nil
      assert errors["quantity"] != nil
      assert errors["idempotency_key"] != nil
    end
  end
end
