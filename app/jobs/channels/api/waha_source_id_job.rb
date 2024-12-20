class Channels::Api::WahaSourceIdJob < ApplicationJob
  queue_as :medium

  # Max retries
  MAX_RETRIES = 10

  def perform(record_id, retry_count = 0)
    Rails.logger.info "Job to check waha message status for #{record_id}"

    message = Message.find(record_id)

    if retry_count >= MAX_RETRIES
      conversation = message.conversation
      params = {
        private: true,
        content: "Mensagem não enviada: #{message.content}",
        content_attributes: { in_reply_to: record_id }
      }
      Messages::MessageBuilder.new(message.sender, conversation, params).perform
      Rails.logger.error "Job failed after #{MAX_RETRIES} retries for record ID #{record_id}"
      return
    end

    unless message.source_id.present?
      Rails.logger.info "Retrying job for record ID #{record_id}, attempt #{retry_count + 1}"
      self.class.set(wait: 10.seconds).perform_later(record_id, retry_count + 1)
    end
  end
end
