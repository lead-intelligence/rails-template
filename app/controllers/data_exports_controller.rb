class DataExportsController < ApplicationController
  include ActiveStorage::Streaming

  rate_limit to: DataExport::REQUEST_LIMIT, within: DataExport::REQUEST_WINDOW, only: :create, by: -> { Current.user.id },
    with: -> { redirect_to edit_profile_path, alert: t("data_exports.rate_limit", count: DataExport::REQUEST_LIMIT) }

  def create
    DataExportJob.perform_later(Current.user)
    redirect_to edit_profile_path, notice: t(".notice")
  end

  def show
    export = Current.user.data_export

    if !export.attached?
      redirect_to edit_profile_path, notice: t(".pending")
    elsif DataExport.expired?(export.attachment)
      export.purge_later
      redirect_to edit_profile_path, notice: t(".expired")
    else
      send_blob_stream export.blob, disposition: :attachment
    end
  end
end
