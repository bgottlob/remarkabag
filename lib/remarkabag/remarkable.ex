defmodule Remarkabag.Remarkable do
  alias Remarkabag.Wallabag.Entry

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
  def upload(%Entry{local_path: local_path}) do
    System.cmd(
      "rmapi",
      ["put", local_path, @device_directory],
      env: [
        {"RMAPI_HOST", Application.get_env(:remarkabag, :remarkable_url)},
        {"RMAPI_CONFIG", Application.get_env(:remarkabag, :rmapi_config)}
      ]
    )
  end
end
