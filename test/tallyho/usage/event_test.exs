defmodule TallyHo.Usage.EventTest do
  use ExUnit.Case, async: true
  alias TallyHo.Usage.Event

  describe "changeset/2" do
    test "valid with valid attributes" do
      attrs = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => 42,
        "idempotency_key" => "key_1"
      }

      changeset = Event.changeset(%Event{}, attrs)
      assert changeset.valid?
    end

    test "invalid with negative quantity" do
      attrs = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => -5,
        "idempotency_key" => "key_1"
      }

      changeset = Event.changeset(%Event{}, attrs)
      refute changeset.valid?
      assert %{quantity: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "invalid when required fields are missing" do
      changeset = Event.changeset(%Event{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors.customer_id != nil
      assert errors.metric != nil
      assert errors.quantity != nil
      assert errors.idempotency_key != nil
    end

    test "invalid with an unrecognized metric" do
      attrs = %{
        "customer_id" => "cust_123",
        "metric" => "totally_made_up_metric",
        "quantity" => 5,
        "idempotency_key" => "key_1"
      }

      changeset = Event.changeset(%Event{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).metric != nil
    end

    test "invalid with a timestamp far in the future" do
      attrs = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => 5,
        "idempotency_key" => "key_1",
        "timestamp" => DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      changeset = Event.changeset(%Event{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).timestamp != nil
    end

    test "valid with a timestamp within the allowed clock-skew window" do
      attrs = %{
        "customer_id" => "cust_123",
        "metric" => "api_requests",
        "quantity" => 5,
        "idempotency_key" => "key_1",
        "timestamp" => DateTime.utc_now() |> DateTime.add(30, :second)
      }

      changeset = Event.changeset(%Event{}, attrs)
      assert changeset.valid?
    end
  end

  # Helper to transform changeset errors into readable map
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
