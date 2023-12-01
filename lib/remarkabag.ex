defmodule Remarkabag do
  use Application
  require Logger

  alias Remarkabag.{Entry, PDF, Remarkable, Rmfakecloud, Wallabag}
  alias :mnesia, as: Mnesia

  @impl true
  def start(_type, _args) do
    children = [
      # {ChromicPDF, chromic_pdf_opts()},
      # {Remarkable, []},
      {Rmfakecloud, []},
      {Wallabag.Downloader, []},
      {Wallabag, []}
      # {PDF, []}
    ]

    :ok = create_mnesia()

    Supervisor.start_link(children, strategy: :one_for_one, name: Remarkabag.Supervisor)
  end

  defp create_mnesia() do
    node = node()

    case Mnesia.create_schema([node]) do
      :ok ->
        Logger.info("Created Mnesia schema for current node #{node}")

      {:error, {^node, {:already_exists, ^node}}} ->
        Logger.info("Mnesia schema already exists on current node #{node}")
    end

    :ok = Entry.create_table()

    :ok
  end

  defp chromic_pdf_opts do
    [
      session_pool: [timeout: 60_000]
    ]
  end
end
