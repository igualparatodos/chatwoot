class Channels::Api::WahaSourceIdJob < ApplicationJob
  queue_as :medium

  # Max retries
  MAX_RETRIES = 5

  def perform(record_id, retry_count = 0)
    message = Message.find(record_id)

    if retry_count >= MAX_RETRIES
      message.update!(status: :failed)
      conversation = message.conversation
      params = {
        private: true,
        content: "Erro, mensagem não enviada",
        in_reply_to: record_id
      }
      Messages::MessageBuilder.new(conversation.user, conversation, params).perform

      Rails.logger.error "Job failed after #{MAX_RETRIES} retries for record ID #{record_id}"
      return
    end

    unless message.source_id.present?
      self.class.set(wait: 5.seconds).perform_later(record_id, retry_count + 1)
    end
  end
end
