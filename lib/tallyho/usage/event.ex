defmodule TallyHo.Usage.Event do
  @enforce_keys [:customer_id, :metric, :quantity]
  defstruct [:customer_id, :metric, :quantity, :idempotency_key, :timestamp]

  @doc """
  Builds and validates a usage event from raw string-keyed params.
  Returns {:ok, %Event{}} or {:error, reason}.
  """
  def new(params) when is_map(params) do
    with {:ok, customer_id} <- validate_present(params["customer_id"], :customer_id),
         {:ok, metric} <- validate_present(params["metric"], :metric),
         {:ok, quantity} <- validate_quantity(params["quantity"]) do
      {:ok,
       %__MODULE__{
         customer_id: customer_id,
         metric: metric,
         quantity: quantity,
         idempotency_key: params["idempotency_key"],
         timestamp: params["timestamp"] || DateTime.utc_now()
       }}
    end
  end

  # defp defines a private function (like unexported lower-case func in Go)
  defp validate_present(val, field) when is_binary(val) do
    trimmed = String.trim(val)
    if trimmed == "", do: {:error, {:blank, field}}, else: {:ok, trimmed}
  end

  defp validate_present(_, field), do: {:error, {:missing, field}}

  # Pattern match on type: integers vs string parsing
  defp validate_quantity(q) when is_integer(q) and q > 0, do: {:ok, q}

  defp validate_quantity(q) when is_binary(q) do
    case Integer.parse(q) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, :invalid_quantity}
    end
  end

  defp validate_quantity(_), do: {:error, :invalid_quantity}
end
