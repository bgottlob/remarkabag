defmodule Remarkabag.Remarkable do
  require Logger
  alias Remarkabag.Entry

  def child_spec([]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link() do
    Logger.info("Starting Remarkable uploader")
    Task.start_link(__MODULE__, :loop, [])
  end

  # 5 minutes between runs
  @sleep 5 * 60 * 1000
  def loop() do
    Enum.each(
      Entry.need_to_remarkable_sync(),
      fn entry ->
        upload(entry.id, entry.downloaded_path)
      end
    )

    Process.sleep(@sleep)
    loop()
  end

  def device_token(code) do
    device_id = UUID.uuid4()

    {_request, response} =
      Req.new(
        url: "#{Application.get_env(:remarkabag, :remarkable_url)}/token/json/2/device/new",
        method: :post
      )
      |> Req.Request.put_header("authorization", "Bearer")
      |> Req.Request.merge_options(
        body: %{
          code: code,
          deviceDesc: "desktop-windows",
          deviceID: device_id
        }
      )
      |> Req.Request.merge_options(json: true)
      |> Req.Request.run_request()

    response.body
  end

  @device_directory "/remarkabag"
  def upload(id, downloaded_path) do
    remarkable_path = "#{@device_directory}/#{Path.basename(downloaded_path)}"

    status =
      System.cmd(
        "rmapi",
        ["put", downloaded_path, @device_directory],
        env: [
          {"RMAPI_HOST", Application.get_env(:remarkabag, :remarkable_url)},
          {"RMAPI_CONFIG", Application.get_env(:remarkabag, :rmapi_config)}
        ],
        stderr_to_stdout: true
      )

    case status do
      {_, 0} ->
        Entry.write_remarkable_synced(id, remarkable_path)

      {out, _} ->
        if String.contains?(out, "Error:  entry already exists") do
          Entry.write_remarkable_synced(id, remarkable_path)
        else
          Logger.error("Error when trying to upload #{downloaded_path} to Remarkable cloud")
        end
    end
  end
end
