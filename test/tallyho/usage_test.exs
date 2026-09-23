defmodule TallyHo.UsageTest do
  use TallyHo.DataCase, async: true
  alias TallyHo.Usage

  # A fixed reference period safely in the past (relative to whenever the
  # test suite actually runs), so period-boundary fixtures never collide
  # with Event's "timestamp can't be in the future" validation.
  @period_start ~U[2026-01-01 00:00:00Z]
  @period_end ~U[2026-02-01 00:00:00Z]
  @period {@period_start, @period_end}

  describe "current_billing_period/1" do
    test "returns the UTC calendar month containing `now`, start inclusive / end exclusive" do
      now = ~U[2026-01-23 14:00:00Z]
      assert Usage.current_billing_period(now) == @period
    end

    test "handles December correctly (year rollover)" do
      now = ~U[2025-12-15 00:00:00Z]

      assert Usage.current_billing_period(now) ==
               {~U[2025-12-01 00:00:00Z], ~U[2026-01-01 00:00:00Z]}
    end
  end

  describe "invoice_line_inputs/2" do
    test "excludes events outside the given period (the original bug: no period boundary at all)" do
      {:ok, _in_period} =
        Usage.ingest_event(%{
          "customer_id" => "cust_period",
          "metric" => "api_requests",
          "quantity" => 100,
          "idempotency_key" => "in_period",
          "timestamp" => DateTime.add(@period_start, 1, :day)
        })

      {:ok, _before_period} =
        Usage.ingest_event(%{
          "customer_id" => "cust_period",
          "metric" => "api_requests",
          "quantity" => 9_999,
          "idempotency_key" => "before_period",
          "timestamp" => DateTime.add(@period_start, -1, :second)
        })

      {:ok, _after_period} =
        Usage.ingest_event(%{
          "customer_id" => "cust_period",
          "metric" => "api_requests",
          "quantity" => 9_999,
          "idempotency_key" => "after_period",
          "timestamp" => @period_end
        })

      assert Usage.invoice_line_inputs("cust_period", @period) ==
               [%{metric: "api_requests", quantity: 100}]
    end

    test "sums correctly across more events than the old hardcoded 50/100 row caps" do
      for n <- 1..120 do
        {:ok, _} =
          Usage.ingest_event(%{
            "customer_id" => "cust_volume",
            "metric" => "api_requests",
            "quantity" => 1,
            "idempotency_key" => "vol_#{n}",
            "timestamp" => DateTime.add(@period_start, 10, :day)
          })
      end

      assert Usage.invoice_line_inputs("cust_volume", @period) ==
               [%{metric: "api_requests", quantity: 120}]
    end

    test "groups by metric independently" do
      {:ok, _} =
        Usage.ingest_event(%{
          "customer_id" => "cust_multi",
          "metric" => "api_requests",
          "quantity" => 10,
          "idempotency_key" => "multi_1",
          "timestamp" => DateTime.add(@period_start, 5, :day)
        })

      {:ok, _} =
        Usage.ingest_event(%{
          "customer_id" => "cust_multi",
          "metric" => "storage_gb",
          "quantity" => 5,
          "idempotency_key" => "multi_2",
          "timestamp" => DateTime.add(@period_start, 5, :day)
        })

      result = Usage.invoice_line_inputs("cust_multi", @period) |> Enum.sort_by(& &1.metric)

      assert result == [
               %{metric: "api_requests", quantity: 10},
               %{metric: "storage_gb", quantity: 5}
             ]
    end
  end
end
