defmodule TallyHo.Usage.Event do
  use Ecto.Schema
  import Ecto.Changeset
  alias TallyHo.Usage.Metrics

  # How far into the future a client-supplied timestamp may claim to be,
  # to tolerate clock skew without letting events land in a future billing
  # period on purpose.
  @max_future_skew_seconds 300

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "events" do
    field :customer_id, :string
    field :metric, :string
    field :quantity, :integer
    field :timestamp, :utc_datetime
    field :idempotency_key, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:customer_id, :metric, :quantity, :timestamp, :idempotency_key])
    |> validate_required([:customer_id, :metric, :quantity, :idempotency_key])
    |> validate_inclusion(:metric, Metrics.known_metrics())
    |> validate_number(:quantity, greater_than: 0)
    |> put_default_timestamp()
    |> validate_not_future(:timestamp)
    |> unique_constraint(:idempotency_key, name: :events_customer_id_idempotency_key_index)
  end

  defp put_default_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end

  defp validate_not_future(changeset, field) do
    validate_change(changeset, field, fn ^field, timestamp ->
      limit = DateTime.add(DateTime.utc_now(), @max_future_skew_seconds, :second)

      if DateTime.compare(timestamp, limit) == :gt do
        [{field, "cannot be in the future"}]
      else
        []
      end
    end)
  end
end
