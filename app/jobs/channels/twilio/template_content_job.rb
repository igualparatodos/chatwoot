class Channels::Twilio::TemplateContentJob < ApplicationJob
  queue_as :medium

  def perform(record_id)
    message = Message.find(record_id)

    twilio_message = channel.fetch_message(message.source_id)

    if twilio_message.body.present?
      message.update!(content: twilio_message.body)
    else
      self.class.set(wait: 1.minute).perform_later(record_id)
    end
  end

  private

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end
end
