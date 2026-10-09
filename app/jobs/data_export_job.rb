class DataExportJob < ApplicationJob
  queue_as :default

  def perform(user)
    Tempfile.create([ "data-export", ".zip" ], binmode: true) do |file|
      DataExport.new(user).write(file)
      file.rewind
      user.data_export.attach(io: file, filename: "data-export.zip", content_type: "application/zip")
    end
    DataExportMailer.ready(user).deliver_later
  end
end
