defmodule TallyHo.Billing.Invoicer do
  @moduledoc """
  Pure functional module for usage-based invoice calculation.
  Uses Decimal for all monetary values to prevent IEEE 754 float inaccuracies.
  """
  alias Decimal, as: D
  alias TallyHo.Usage.Metrics

  defmodule LineItem do
    @moduledoc "One priced row of an invoice: a metric, its usage, and its cost."
    defstruct [:metric, :total_quantity, :unit_price, :total_amount]
  end

  defmodule Invoice do
    @moduledoc "A customer's line items and total for a given set of events."
    defstruct [:customer_id, :line_items, :total_amount]
  end

  @doc """
  Calculates an invoice given a customer_id and a list of event structs/maps.
  """
  def calculate_invoice(customer_id, events) when is_list(events) do
    line_items =
      events
      |> Enum.group_by(& &1.metric)
      |> Enum.map(fn {metric, metric_events} ->
        total_quantity = Enum.reduce(metric_events, 0, fn e, acc -> acc + e.quantity end)
        unit_price = Metrics.rate_for(metric) || D.new("0.00")
        total_amount = D.mult(unit_price, D.new(total_quantity))

        %LineItem{
          metric: metric,
          total_quantity: total_quantity,
          unit_price: unit_price,
          total_amount: total_amount
        }
      end)
      |> Enum.sort_by(& &1.metric)

    total_amount =
      Enum.reduce(line_items, D.new("0.00"), fn item, acc ->
        D.add(acc, item.total_amount)
      end)

    %Invoice{
      customer_id: customer_id,
      line_items: line_items,
      total_amount: total_amount
    }
  end
end
