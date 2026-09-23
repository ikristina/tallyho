defmodule TallyHo.Usage.EventTest do
  use ExUnit.Case, async: true
  alias TallyHo.Usage.Event

  describe "new/1" do
    test "builds an event with valid integer quantity" do
      params = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => 42
      }

      assert {:ok, %Event{} = event} = Event.new(params)
      assert event.customer_id == "cust_123"
      assert event.metric == "api_requests"
      assert event.quantity == 42
      assert %DateTime{} = event.timestamp
    end

    test "parses string quantity" do
      params = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => "100"
      }

      assert {:ok, %Event{quantity: 100}} = Event.new(params)
    end

    test "returns error on negative quantity" do
      params = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => -5
      }

      assert {:error, :invalid_quantity} = Event.new(params)
    end

    test "returns error when customer_id is blank" do
      params = %{
        "customer_id" => "   ",
        "metric" => "api_requests",
        "quantity" => 5
      }

      assert {:error, {:blank, :customer_id}} = Event.new(params)
    end
  end
end
