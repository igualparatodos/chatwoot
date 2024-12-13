class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    message.update!(status: :sent, content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  def set_external_source
    ActiveRecord::Base.transaction do
      message.update!(source_id: set_external_identifier_params[:source_id])
    end
  end

  def set_sent
    message = Message.find_by!(source_id: set_external_identifier_params[:source_id]) if message.blank?

    ActiveRecord::Base.transaction do
      message.update!(status: :sent)
    end
  end

  def set_read
    message = Message.find_by!(source_id: set_external_identifier_params[:source_id]) if message.blank?

    ActiveRecord::Base.transaction do
      message.update!(status: :read)
    end
  end


  def set_failed
    message = Message.find_by!(source_id: set_external_identifier_params[:source_id]) if message.blank?

    ActiveRecord::Base.transaction do
      message.update!(status: :failed)
    end
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language)
  end

  def set_external_identifier_params
    params.permit(:id, :source_id)
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end
end
