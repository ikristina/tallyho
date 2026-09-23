defmodule TallyHoWeb.EventControllerTest do
  use TallyHoWeb.ConnCase, async: true

  @valid_attrs %{
    "customer_id" => "cust_123",
    "metric" => "api_requests",
    "quantity" => 42,
    "idempotency_key" => "idem_001"
  }

  describe "POST /api/events without a valid API key" do
    test "rejects with 401 when the Authorization header is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/events", @valid_attrs)
      assert json_response(conn, 401)
    end

    test "rejects with 401 when the key is wrong", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer nonsense")
        |> post(~p"/api/events", @valid_attrs)

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/events" do
    setup %{conn: conn} do
      {:ok, conn: with_api_key(conn)}
    end

    test "ingests a valid event and returns 201 Created", %{conn: conn} do
      conn = post(conn, ~p"/api/events", @valid_attrs)

      assert %{"status" => "success", "data" => data} = json_response(conn, 201)
      assert data["customer_id"] == "cust_123"
      assert data["metric"] == "api_requests"
      assert data["quantity"] == 42
      assert data["id"] != nil
    end

    test "rejects duplicate idempotency_key for the same customer with 409 Conflict", %{
      conn: conn
    } do
      conn1 = post(conn, ~p"/api/events", @valid_attrs)
      assert json_response(conn1, 201)

      # Second post with identical idempotency_key
      conn2 = post(conn, ~p"/api/events", @valid_attrs)
      assert %{"error" => msg} = json_response(conn2, 409)
      assert msg =~ "Duplicate idempotency_key"
    end

    test "allows two different customers to reuse the same idempotency_key", %{conn: conn} do
      conn1 = post(conn, ~p"/api/events", @valid_attrs)
      assert json_response(conn1, 201)

      other_customer_attrs = %{@valid_attrs | "customer_id" => "cust_456"}
      conn2 = post(conn, ~p"/api/events", other_customer_attrs)
      assert json_response(conn2, 201)
    end

    test "returns 422 with validation errors for invalid input", %{conn: conn} do
      invalid_attrs = %{"customer_id" => "", "quantity" => -1}
      conn = post(conn, ~p"/api/events", invalid_attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["customer_id"] != nil
      assert errors["quantity"] != nil
      assert errors["idempotency_key"] != nil
    end

    test "rejects an unrecognized metric with 422 instead of silently zero-pricing it", %{
      conn: conn
    } do
      attrs = %{
        @valid_attrs
        | "metric" => "totally_made_up_metric",
          "idempotency_key" => "idem_unknown_metric"
      }

      conn = post(conn, ~p"/api/events", attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["metric"] != nil
    end

    test "rejects a timestamp more than a few minutes in the future with 422", %{conn: conn} do
      attrs =
        @valid_attrs
        |> Map.put("idempotency_key", "idem_future_ts")
        |> Map.put("timestamp", "2099-01-01T00:00:00Z")

      conn = post(conn, ~p"/api/events", attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["timestamp"] != nil
    end
  end
end
