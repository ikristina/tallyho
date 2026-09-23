defmodule TallyHo.Usage.Event do
  use Ecto.Schema
  import Ecto.Changeset

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
    |> validate_number(:quantity, greater_than: 0)
    |> put_default_timestamp()
    |> unique_constraint(:idempotency_key)
  end

  defp put_default_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
