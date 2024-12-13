class Channels::Twilio::TemplateContentJob < ApplicationJob
  queue_as :medium

  # Max retries
  MAX_RETRIES = 5

  def perform(record_id, retry_count = 0)
    message = Message.find(record_id)
    inbox = message.inbox
    channel = inbox.channel

    if retry_count >= MAX_RETRIES
      Rails.logger.error "Job failed after #{MAX_RETRIES} retries for record ID #{record_id}"
      return
    end

    twilio_message = channel.fetch_message(message.source_id)

    if twilio_message.body.present?
      message.update!(content: twilio_message.body)
    else
      self.class.set(wait: 5.seconds).perform_later(record_id, retry_count + 1)
    end
  end
end
