defmodule TallyHoWeb.DashboardLive do
  use TallyHoWeb, :live_view
  alias TallyHo.Billing.Invoicer
  alias TallyHo.Usage

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    customer_id = Map.get(params, "customer_id", "cust_123")

    if connected?(socket) do
      Usage.subscribe_customer(customer_id)
    end

    events = Usage.list_customer_events(customer_id)

    {:noreply,
     socket
     |> assign(:customer_id, customer_id)
     |> assign_current_invoice()
     |> stream(:events, events, reset: true)}
  end

  @impl true
  def handle_event("switch_customer", %{"customer_id" => id}, socket) do
    target =
      case String.trim(id) do
        "" -> "cust_123"
        clean -> clean
      end

    {:noreply, push_patch(socket, to: ~p"/dashboard/#{target}")}
  end

  @impl true
  def handle_info({:event_ingested, event}, socket) do
    if event.customer_id == socket.assigns.customer_id do
      {:noreply,
       socket
       |> stream_insert(:events, event, at: 0)
       |> assign_current_invoice()}
    else
      {:noreply, socket}
    end
  end

  # Recomputes the invoice from the DB for the customer's *current* UTC
  # billing period, rather than from whatever events happen to be in the
  # live activity stream. Same query on mount and on every PubSub update,
  # so the total never depends on which code path last ran.
  defp assign_current_invoice(socket) do
    customer_id = socket.assigns.customer_id
    period = Usage.current_billing_period()
    line_inputs = Usage.invoice_line_inputs(customer_id, period)
    invoice = Invoicer.calculate_invoice(customer_id, line_inputs)

    socket
    |> assign(:invoice, invoice)
    |> assign(:period, period)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-6xl mx-auto px-4 py-8 space-y-8">
        <%!-- Header & Switcher --%>
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-zinc-200 dark:border-zinc-800">
          <div>
            <div class="flex items-center gap-2">
              <span class="inline-flex items-center justify-center p-2 bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 dark:text-indigo-400 rounded-lg">
                <.icon name="hero-bolt" class="w-6 h-6" />
              </span>
              <h1 class="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">
                Usage & Invoicing Dashboard
              </h1>
            </div>
            <p class="text-sm text-zinc-500 dark:text-zinc-400 mt-1">
              Real-time usage metering powered by Phoenix LiveView and PubSub
            </p>
          </div>

          <form phx-submit="switch_customer" class="flex items-center gap-2">
            <input
              type="text"
              name="customer_id"
              value={@customer_id}
              placeholder="Customer ID..."
              class="px-3 py-2 text-sm rounded-lg border border-zinc-300 dark:border-zinc-700 bg-white dark:bg-zinc-900 text-zinc-900 dark:text-zinc-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white transition-colors"
            >
              Switch
            </button>
          </form>
        </div>

        <%!-- Running Invoice Card --%>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-1 p-6 rounded-2xl bg-linear-to-br from-indigo-900 via-indigo-950 to-zinc-950 text-white shadow-xl border border-indigo-800/40 relative overflow-hidden">
            <span class="text-xs uppercase tracking-wider font-semibold text-indigo-300">
              Current Period Total
            </span>
            <div class="mt-2 text-4xl font-extrabold tracking-tight">
              ${Decimal.to_string(@invoice.total_amount, :normal)}
            </div>
            <p class="mt-2 text-xs text-indigo-200/70">
              Customer: <span class="font-mono text-white font-medium">{@customer_id}</span>
            </p>
            <p class="mt-1 text-xs text-indigo-200/70">
              Billing period: <span class="font-mono text-white/90">{period_label(@period)}</span>
              (UTC)
            </p>
            <div class="mt-6 pt-4 border-t border-indigo-800/50 flex items-center justify-between text-xs text-indigo-300">
              <span class="flex items-center gap-1.5">
                <span class="relative flex h-2 w-2">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                  <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                </span>
                Live PubSub Active
              </span>
              <span>USD</span>
            </div>
          </div>

          <%!-- Usage Breakdown --%>
          <div class="lg:col-span-2 p-6 rounded-2xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 shadow-sm">
            <h2 class="text-base font-semibold text-zinc-900 dark:text-zinc-100 mb-4">
              Usage by Metric
            </h2>
            <%= if @invoice.line_items == [] do %>
              <div class="text-sm text-zinc-500 dark:text-zinc-400 py-6 text-center">
                No usage recorded yet for this customer.
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for item <- @invoice.line_items do %>
                  <div class="flex items-center justify-between p-3 rounded-xl bg-zinc-50 dark:bg-zinc-800/50 border border-zinc-100 dark:border-zinc-800">
                    <div>
                      <div class="font-mono font-medium text-sm text-zinc-900 dark:text-zinc-100">
                        {item.metric}
                      </div>
                      <div class="text-xs text-zinc-500">
                        {item.total_quantity} units @ ${Decimal.to_string(item.unit_price, :normal)}/unit
                      </div>
                    </div>
                    <div class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
                      ${Decimal.to_string(item.total_amount, :normal)}
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Live Events Stream --%>
        <div class="rounded-2xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-zinc-200 dark:border-zinc-800 flex items-center justify-between">
            <h2 class="text-base font-semibold text-zinc-900 dark:text-zinc-100">
              Live Ingested Events Stream
            </h2>
            <span class="text-xs text-zinc-400 font-mono">Stream updates in real-time</span>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-zinc-600 dark:text-zinc-300">
              <thead class="text-xs uppercase bg-zinc-50 dark:bg-zinc-800/60 text-zinc-500 border-b border-zinc-200 dark:border-zinc-800">
                <tr>
                  <th class="px-6 py-3">Metric</th>
                  <th class="px-6 py-3">Quantity</th>
                  <th class="px-6 py-3">Timestamp</th>
                  <th class="px-6 py-3">Idempotency Key</th>
                </tr>
              </thead>
              <tbody id="events" phx-update="stream">
                <tr id="empty-events" class="hidden only:table-row">
                  <td colspan="4" class="px-6 py-8 text-center text-zinc-400">
                    No events received yet. Post to /api/events to stream live!
                  </td>
                </tr>
                <tr
                  :for={{dom_id, event} <- @streams.events}
                  id={dom_id}
                  class="border-b border-zinc-100 dark:border-zinc-800/50 hover:bg-zinc-50/50 dark:hover:bg-zinc-800/30 transition-colors"
                >
                  <td class="px-6 py-3.5 font-medium font-mono text-zinc-900 dark:text-zinc-100">
                    {event.metric}
                  </td>
                  <td class="px-6 py-3.5 font-semibold text-indigo-600 dark:text-indigo-400">
                    +{event.quantity}
                  </td>
                  <td class="px-6 py-3.5 text-xs text-zinc-500">
                    {Calendar.strftime(event.timestamp, "%Y-%m-%d %H:%M:%S UTC")}
                  </td>
                  <td class="px-6 py-3.5 font-mono text-xs text-zinc-400">
                    {event.idempotency_key}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # `period_end` is exclusive (the first instant of next month), so the
  # human-readable label shows the last actual day of the period, not it.
  defp period_label({period_start, period_end}) do
    last_day = Date.add(DateTime.to_date(period_end), -1)
    "#{Calendar.strftime(period_start, "%b %-d")}–#{Calendar.strftime(last_day, "%b %-d, %Y")}"
  end
end
