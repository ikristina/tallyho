defmodule TallyHo.Usage.Metrics do
  @moduledoc """
  Canonical registry of billable usage metrics and their unit prices (USD).

  This is the single source of truth for what a "known" metric is. Both
  ingestion (`TallyHo.Usage.Event` validation) and pricing
  (`TallyHo.Billing.Invoicer`) read from here, so a metric can never be
  accepted at the API without a price, or priced without having been an
  accepted metric.
  """
  alias Decimal, as: D

  @rates %{
    "api_requests" => D.new("0.001"),
    "storage_gb" => D.new("0.05"),
    "compute_hours" => D.new("0.10")
  }

  @doc "The list of metric names accepted at ingestion."
  def known_metrics, do: Map.keys(@rates)

  @doc "Unit price for a metric, or `nil` if the metric isn't known."
  def rate_for(metric), do: Map.get(@rates, metric)
end
