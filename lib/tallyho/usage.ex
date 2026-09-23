defmodule TallyHo.Usage do
  @moduledoc """
  The Usage context. Public boundary for event ingestion and queries.
  """
  import Ecto.Query
  alias TallyHo.Repo
  alias TallyHo.Usage.Event

  @topic_prefix "customer_usage:"

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

  def list_customer_events(customer_id, limit \\ 50) do
    Event
    |> where([e], e.customer_id == ^customer_id)
    |> order_by([e], desc: e.timestamp, desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
