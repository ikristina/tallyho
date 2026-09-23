defmodule TallyHo.Usage do
  @moduledoc """
  The Usage context. Public boundary for event ingestion and queries.
  """
  import Ecto.Query
  alias TallyHo.Repo
  alias TallyHo.Usage.Event

  @doc """
  Ingests an event with idempotency protection.
  Returns:
    - {:ok, %Event{}} on success
    - {:error, %Ecto.Changeset{}} on validation or duplicate idempotency_key
  """
  def ingest_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns all events for a customer within an optional timestamp range.
  """
  def list_customer_events(customer_id) do
    Event
    |> where([e], e.customer_id == ^customer_id)
    |> order_by([e], desc: e.timestamp)
    |> Repo.all()
  end
end
