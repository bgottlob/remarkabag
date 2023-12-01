defmodule Remarkabag.Rmfakecloud do
  require Logger
  alias Remarkabag.Entry

  @cookie_key :".Authrmfakecloud"

  def child_spec([]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link() do
    Logger.info("Starting rmfakecloud uploader")
    Task.start_link(__MODULE__, :loop, [])
  end

  @sleep 5 * 1000
  def loop() do
    {:ok, [set_cookie]} = login()

    Logger.info("Looping rmfakecloud sync")

    Enum.each(
      Entry.need_to_remarkable_sync(),
      fn entry ->
        # This call is pretty wasteful since it asks for all documents
        {:ok, docs} = documents(set_cookie)

        # Assumes the remarkabag directory exists and its only one level deep
        dir_item =
          docs
          |> Map.fetch!("Entries")
          |> Enum.find(fn %{"name" => name} -> name == "remarkabag" end)

        dir_id = Map.fetch!(dir_item, "id")

        existing_doc =
          dir_item
          |> Map.fetch!("children")
          |> Enum.find(fn %{"name" => name} -> name == entry.title end)

        doc_id =
          case existing_doc do
            nil ->
              Logger.debug("Uploading #{entry.downloaded_path}")

              case upload(set_cookie, dir_id, entry.downloaded_path) do
                {:ok, id} -> id
                _ -> nil
              end

            _ ->
              Logger.debug("There is already a document called #{entry.title}")
              Map.fetch!(existing_doc, "id")
          end

        if doc_id != nil do
          Entry.write_remarkable_synced(entry.id, "#{dir_id}/#{doc_id}")
        end
      end
    )

    Process.sleep(@sleep)
    loop()
  end

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
        method: :get,
        headers: [{"Cookie", Cookie.serialize({@cookie_key, cookie})}]
      )
      |> Req.Request.run_request()

    case response.status do
      200 ->
        {:ok, response.body}

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

    {:ok, response} =
      Tesla.post(client, "/ui/api/documents/upload", mp,
        headers: [
          {"Content-Type", "multipart/form-data"},
          {"Cookie", Cookie.serialize({@cookie_key, cookie})}
        ]
      )

    case response.status do
      200 ->
        case Jason.decode!(response.body) do
          [record] ->
            {:ok, Map.fetch!(record, "ID")}

          [] ->
            Logger.error(
              "Upload of #{file_path} to rmfakecloud returned a 200 with an empty response body"
            )
        end

      s ->
        Logger.error("Login to rmfakecloud failed with status code #{s}:\n\t#{response.body}")
    end
  end
end
