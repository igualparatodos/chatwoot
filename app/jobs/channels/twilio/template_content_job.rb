class Channels::Twilio::TemplateContentJob < ApplicationJob
  queue_as :medium

  def perform(record_id)
    message = Message.find(record_id)
    inbox = message.inbox
    channel = inbox.channel

    twilio_message = channel.fetch_message(message.source_id)

    if twilio_message.body.present?
      message.update!(content: twilio_message.body)
    else
      self.class.set(wait: 5.seconds).perform_later(record_id)
    end
  end
end
