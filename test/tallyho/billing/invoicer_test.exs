defmodule TallyHo.Billing.InvoicerTest do
  use ExUnit.Case, async: true
  alias Decimal, as: D
  alias TallyHo.Billing.Invoicer

  describe "calculate_invoice/2" do
    test "returns zero total for customer with no events" do
      invoice = Invoicer.calculate_invoice("cust_empty", [])

      assert invoice.customer_id == "cust_empty"
      assert invoice.line_items == []
      assert D.equal?(invoice.total_amount, D.new("0.00"))
    end

    test "aggregates multiple events for the same metric" do
      events = [
        %{metric: "api_requests", quantity: 1500},
        %{metric: "api_requests", quantity: 3500}
      ]

      invoice = Invoicer.calculate_invoice("cust_1", events)

      assert length(invoice.line_items) == 1
      [item] = invoice.line_items

      assert item.metric == "api_requests"
      assert item.total_quantity == 5000
      assert D.equal?(item.unit_price, D.new("0.001"))
      assert D.equal?(item.total_amount, D.new("5.00"))
      assert D.equal?(invoice.total_amount, D.new("5.00"))
    end

    test "calculates multi-metric invoice with precise totals" do
      events = [
        # 2000 * 0.001 = $2.00
        %{metric: "api_requests", quantity: 2000},
        # 50 * 0.05    = $2.50
        %{metric: "storage_gb", quantity: 50},
        # 10 * 0.10    = $1.00
        %{metric: "compute_hours", quantity: 10}
      ]

      invoice = Invoicer.calculate_invoice("cust_multi", events)

      assert length(invoice.line_items) == 3
      # Total: 2.00 + 2.50 + 1.00 = 5.50
      assert D.equal?(invoice.total_amount, D.new("5.50"))
    end

    test "gracefully handles unrecognized metrics with 0.00 rate" do
      events = [%{metric: "unknown_custom_metric", quantity: 100}]

      invoice = Invoicer.calculate_invoice("cust_unknown", events)
      [item] = invoice.line_items

      assert D.equal?(item.unit_price, D.new("0.00"))
      assert D.equal?(item.total_amount, D.new("0.00"))
      assert D.equal?(invoice.total_amount, D.new("0.00"))
    end
  end
end
