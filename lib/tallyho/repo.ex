defmodule TallyHo.Repo do
  use Ecto.Repo,
    otp_app: :tallyho,
    adapter: Ecto.Adapters.Postgres
end
