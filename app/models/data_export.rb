require "zip"

class DataExport
  EXCLUDED_COLUMNS = {
    "User" => %w[password_digest],
    "Document" => %w[embedding]
  }.freeze

  EXCLUDED_ATTACHMENTS = %w[data_export].freeze

  RETENTION = 48.hours

  def self.purge_expired
    ActiveStorage::Attachment
      .where(name: "data_export", created_at: ..RETENTION.ago)
      .find_each(&:purge_later)
  end

  def initialize(user)
    @user = user
  end

  def write(io)
    Zip::OutputStream.write_buffer(io) do |zip|
      zip.put_next_entry("data.json")
      zip.write(JSON.pretty_generate(data))
      each_attachment do |path, attachment|
        zip.put_next_entry(path, nil, nil, Zip::Entry::STORED)
        attachment.blob.download { |chunk| zip.write(chunk) }
      end
    end
  end

  private

  attr_reader :user

  def data
    { "user" => serialize(user) }.merge(associations_data)
  end

  def associations_data
    exported_associations.to_h do |reflection|
      [ reflection.name.to_s, records_for(reflection).map { |record| serialize(record) } ]
    end
  end

  def records_for(reflection)
    names = rich_text_reflections(reflection.klass).map(&:name)
    names.any? ? user.public_send(reflection.name).includes(names) : user.public_send(reflection.name)
  end

  def exported_associations
    User.reflect_on_all_associations.select do |reflection|
      reflection.options[:dependent] == :destroy && domain_association?(reflection)
    end
  end

  def domain_association?(reflection)
    !reflection.klass.name.start_with?("ActiveStorage::", "ActionText::")
  end

  def serialize(record)
    json = record.as_json(except: EXCLUDED_COLUMNS[record.class.name])
    rich_text_reflections(record.class).each do |reflection|
      json[reflection.name.to_s.delete_prefix("rich_text_")] = record.public_send(reflection.name)&.to_plain_text
    end
    json
  end

  def rich_text_reflections(klass)
    klass.reflect_on_all_associations.select { |reflection| reflection.options[:class_name] == "ActionText::RichText" }
  end

  def each_attachment
    attachments(User, user.id).each { |attachment| yield "files/user/#{attachment.name}/#{attachment.blob.filename}", attachment }
    exported_associations.each do |reflection|
      next if reflection.klass.reflect_on_all_attachments.empty?

      attachments(reflection.klass, user.public_send(reflection.name).select(:id)).each do |attachment|
        yield "files/#{reflection.name}/#{attachment.record_id}/#{attachment.name}/#{attachment.blob.filename}", attachment
      end
    end
  end

  def attachments(klass, ids)
    ActiveStorage::Attachment.where(record_type: klass.polymorphic_name, record_id: ids).where.not(name: EXCLUDED_ATTACHMENTS).includes(:blob)
  end
end
