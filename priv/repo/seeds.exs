# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# A few demo events for the default dashboard customer (cust_123), so the
# dashboard shows something on first run instead of an empty state.

demo_events = [
  %{"metric" => "api_requests", "quantity" => 12_500, "idempotency_key" => "seed_api_1"},
  %{"metric" => "api_requests", "quantity" => 3_200, "idempotency_key" => "seed_api_2"},
  %{"metric" => "storage_gb", "quantity" => 42, "idempotency_key" => "seed_storage_1"},
  %{"metric" => "compute_hours", "quantity" => 8, "idempotency_key" => "seed_compute_1"}
]

for attrs <- demo_events do
  case TallyHo.Usage.ingest_event(Map.put(attrs, "customer_id", "cust_123")) do
    {:ok, _event} -> :ok
    # Re-running the seeds script is a no-op past the first run.
    {:error, _changeset} -> :ok
  end
end
