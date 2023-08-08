defmodule Remarkabag do
  use Application

  alias Remarkabag.{PDF, Remarkable, Wallabag}

  @impl true
  def start(_type, _args) do
    children = [
      {ChromicPDF, chromic_pdf_opts()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Remarkabag.Supervisor)
  end

  defp chromic_pdf_opts do
    [
      session_pool: [timeout: 60_000]
    ]
  end

  def run() do
    Wallabag.oauth_client()
    |> Wallabag.all_entries()
    |> Enum.each(fn entry ->
      entry
      |> PDF.download_entry()
      |> Remarkable.upload()
    end)
  end
end
