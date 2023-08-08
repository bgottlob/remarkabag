defmodule Remarkabag.PDF do
  alias Remarkabag.Wallabag.Entry

  @directory "/tmp/remarkabag/papeer"
  def download_entry(entry = %Entry{title: title, url: url}) do
    File.mkdir_p!(@directory)
    file_path = "#{@directory}/#{String.replace(title, "/", "_")}.pdf"
    ChromicPDF.print_to_pdf({:url, url}, output: file_path)
    Map.put(entry, :local_path, file_path)
  end
end
