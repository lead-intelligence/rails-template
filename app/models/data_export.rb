require "zip"

class DataExport
  EXCLUDED_COLUMNS = {
    "User" => %w[password_digest],
    "Document" => %w[embedding],
    "Message" => %w[content_raw raw_content raw_reasoning thinking_signature cache_until_here],
    "RubyLLM::ActiveRecord::ToolCall" => %w[thought_signature]
  }.freeze

  EXCLUDED_ATTACHMENTS = %w[data_export].freeze

  RECORD_SCOPES = { "Message" => :visible_to_person }.freeze

  RETENTION = 48.hours

  REQUEST_LIMIT = 3
  REQUEST_WINDOW = 1.hour

  def self.purge_expired
    ActiveStorage::Attachment
      .where(name: "data_export", created_at: ..RETENTION.ago)
      .find_each(&:purge_later)
  end

  def initialize(user)
    @user = user
  end

  def write(io)
    missing_files = []
    Zip::OutputStream.write_buffer(io) do |zip|
      each_attachment do |path, attachment|
        next missing_files << path unless attachment.blob.service.exist?(attachment.blob.key)

        zip.put_next_entry(path, nil, nil, Zip::Entry::STORED)
        attachment.blob.download { |chunk| zip.write(chunk) }
      end
      zip.put_next_entry("data.json")
      zip.write(JSON.pretty_generate(data.merge("missing_files" => missing_files)))
    end
  end

  private

  attr_reader :user

  def data
    { "user" => serialize(user) }.merge(
      exported_relations.transform_values do |relation|
        relation.includes(rich_text_reflections(relation.klass).map(&:name)).map { |record| serialize(record) }
      end
    )
  end

  def exported_relations
    @exported_relations ||= relations_under(User.where(id: user.id))
  end

  def relations_under(parent, prefix = nil)
    destroyed_associations(parent.klass).each_with_object({}) do |reflection, relations|
      path = [ prefix, reflection.name ].compact.join("/")
      relations[path] = scoped(child_relation(parent, reflection))
      relations.merge!(relations_under(relations[path], path))
    end
  end

  def child_relation(parent, reflection)
    klass = reflection.klass
    klass.where(klass.primary_key => parent.joins(reflection.name).select(klass.arel_table[klass.primary_key]))
  end

  def scoped(relation)
    scope = RECORD_SCOPES[relation.klass.name]
    scope ? relation.public_send(scope) : relation
  end

  def destroyed_associations(klass)
    klass.reflect_on_all_associations.select do |reflection|
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
    attachments(User, user.id).each { |attachment| yield path_for("user", attachment), attachment }
    exported_relations.each do |path, relation|
      next if relation.klass.reflect_on_all_attachments.empty?

      attachments(relation.klass, relation.select(:id)).each do |attachment|
        yield path_for("#{path}/#{attachment.record_id}", attachment), attachment
      end
    end
  end

  def path_for(prefix, attachment)
    "files/#{prefix}/#{attachment.name}/#{attachment.id}/#{attachment.blob.filename}"
  end

  def attachments(klass, ids)
    ActiveStorage::Attachment.where(record_type: klass.polymorphic_name, record_id: ids).where.not(name: EXCLUDED_ATTACHMENTS).includes(:blob)
  end
end
