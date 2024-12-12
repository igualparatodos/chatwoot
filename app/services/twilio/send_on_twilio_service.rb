class Twilio::SendOnTwilioService < Base::SendOnChannelService
  private

  def channel_class
    Channel::TwilioSms
  end

  def perform_reply
    begin
      twilio_message = channel.send_message(**message_params)
      if message.content_attributes.dig(:template_id)
        sent_twilio_message = client.messages(twilio_message.sid).fetch
        message.update!(source_id: twilio_message.sid, content: sent_twilio_message.body) if sent_twilio_message
      end

    rescue Twilio::REST::TwilioError, Twilio::REST::RestError => e
      message.update!(status: :failed, external_error: e.message)
    end
    message.update!(source_id: twilio_message.sid) if twilio_message
  end

  def message_params
    {
      body: message.content,
      to: contact_inbox.source_id,
      media_url: attachments,
      template_id: message.content_attributes.dig(:template_id),
      template_variables: message.content_attributes.dig(:template_variables)
    }
  end

  def attachments
    message.attachments.map(&:download_url)
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end

  def outgoing_message?
    message.outgoing? || message.template?
  end
end
