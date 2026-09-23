defmodule TallyHo.Usage do
  @moduledoc """
  The Usage context. Public boundary for event ingestion and queries.
  """
  import Ecto.Query
  alias TallyHo.Repo
  alias TallyHo.Usage.Event

  @topic_prefix "customer_usage:"
  @recent_events_limit 50

  def subscribe_customer(customer_id) do
    Phoenix.PubSub.subscribe(TallyHo.PubSub, @topic_prefix <> customer_id)
  end

  def ingest_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, event} = success ->
        Phoenix.PubSub.broadcast(
          TallyHo.PubSub,
          @topic_prefix <> event.customer_id,
          {:event_ingested, event}
        )

        success

      error ->
        error
    end
  end

  @doc """
  Most recent events for a customer, for the live activity feed. This is a
  display window, not a billing boundary — use `invoice_line_inputs/2` for
  anything that has to add up correctly.
  """
  def list_customer_events(customer_id, limit \\ @recent_events_limit) do
    Event
    |> where([e], e.customer_id == ^customer_id)
    |> order_by([e], desc: e.timestamp, desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  The UTC calendar-month billing period containing `now`: `{start, end}`,
  start inclusive, end exclusive. Both bounds are `DateTime` at 00:00:00 UTC.
  """
  def current_billing_period(now \\ DateTime.utc_now()) do
    period_start_date = now |> DateTime.to_date() |> Date.beginning_of_month()
    period_end_date = period_start_date |> Date.end_of_month() |> Date.add(1)

    {:ok, period_start} = DateTime.new(period_start_date, ~T[00:00:00], "Etc/UTC")
    {:ok, period_end} = DateTime.new(period_end_date, ~T[00:00:00], "Etc/UTC")

    {period_start, period_end}
  end

  @doc """
  Per-metric summed quantities for a customer within `{period_start,
  period_end}`, computed as a single DB aggregate (`SUM` grouped by metric)
  rather than fetching and summing rows in the app. Unbounded by row count,
  so it stays correct regardless of how many events the customer has.

  Returns `[%{metric: metric, quantity: total_quantity}, ...]`, shaped to
  drop straight into `TallyHo.Billing.Invoicer.calculate_invoice/2`.
  """
  def invoice_line_inputs(customer_id, {period_start, period_end}) do
    Event
    |> where([e], e.customer_id == ^customer_id)
    |> where([e], e.timestamp >= ^period_start and e.timestamp < ^period_end)
    |> group_by([e], e.metric)
    |> select([e], %{metric: e.metric, quantity: sum(e.quantity)})
    |> Repo.all()
  end
end
