defmodule Remarkabag.Rmfakecloud do
  require Logger

  @cookie_key :".Authrmfakecloud"

  defp base_url(), do: Application.get_env(:remarkabag, :rmfakecloud_url)

  def login() do
    {_request, response} =
      Req.new(
        url: "#{base_url()}/ui/api/login",
        method: :post,
        body:
          Jason.encode!(%{
            email: Application.get_env(:remarkabag, :rmfakecloud_username),
            password: Application.get_env(:remarkabag, :rmfakecloud_password)
          })
          |> IO.inspect()
      )
      |> Req.Request.put_header("Content-Type", "application/json")
      |> Req.Request.run_request()

    case response.status do
      200 ->
        {:ok, Req.Response.get_header(response, "set-cookie")}

      s ->
        Logger.error("Login to rmfakecloud failed with status code #{s}:\n\t#{response.body}")
    end
  end

  defp documents(set_cookie) do
    cookie = SetCookie.parse(set_cookie) |> Map.fetch!(:value)

    {_request, response} =
      Req.new(
        url: "#{base_url()}/ui/api/documents",
        method: :get
      )
      |> Req.Request.run_request()

    case response.status do
      200 ->
        {:ok, Jason.decode!(response.body)}

      s ->
        Logger.error("Unable to list documents #{s}:\n\t#{response.body}")
    end
  end

  def upload_directory_id(set_cookie) do
    cookie = SetCookie.parse(set_cookie) |> Map.fetch!(:value)

    {:ok, docs} = documents(set_cookie)

    Map.fetch!(docs, "Entries")
    |> Enum.find_value(fn %{"id" => id, "name" => name, "isFolder" => is_folder} ->
      if name == "remarkabag" && is_folder == true, do: id
    end)
  end

  def upload(set_cookie, parent_id, file_path) do
    cookie = SetCookie.parse(set_cookie) |> Map.fetch!(:value)

    mp =
      Tesla.Multipart.new()
      |> Tesla.Multipart.add_field("parent", parent_id)
      |> Tesla.Multipart.add_content_type_param("charset=utf8")
      |> Tesla.Multipart.add_file(file_path)

    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, Application.get_env(:remarkabag, :rmfakecloud_url)}
      ])

    response =
      Tesla.post(client, "/ui/api/documents/upload", mp,
        headers: [
          {"Cookie", Cookie.serialize({@cookie_key, cookie})}
        ]
      )
      |> IO.inspect()
  end
end
