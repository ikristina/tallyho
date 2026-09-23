defmodule TallyHo.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :customer_id, :string, null: false
      add :metric, :string, null: false
      add :quantity, :integer, null: false
      add :timestamp, :utc_datetime, null: false
      add :idempotency_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # Crucial for billing: prevent duplicate event processing
    create unique_index(:events, [:idempotency_key])
    create index(:events, [:customer_id, :timestamp])
  end
end
