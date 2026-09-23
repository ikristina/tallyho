defmodule TallyHoWeb.EventController do
  use TallyHoWeb, :controller
  alias TallyHo.Usage

  def create(conn, event_params) do
    case Usage.ingest_event(event_params) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          data: %{
            id: event.id,
            customer_id: event.customer_id,
            metric: event.metric,
            quantity: event.quantity,
            timestamp: event.timestamp
          }
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        if idempotency_conflict?(changeset) do
          conn
          |> put_status(:conflict)
          |> json(%{error: "Duplicate idempotency_key: event already processed"})
        else
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  defp idempotency_conflict?(changeset) do
    Enum.any?(changeset.errors, fn {field, {_msg, opts}} ->
      field == :idempotency_key && opts[:constraint] == :unique
    end)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
