# This Builder will create a contact inbox with specified attributes. If the contact inbox already exists, it will be returned.
# For Specific Channels like whatsapp, email etc . it smartly generated appropriate the source id when none is provided.

class ContactInboxBuilder
  pattr_initialize [:contact, :inbox, :source_id, { hmac_verified: false }]

  def perform
    @source_id ||= generate_source_id
    create_contact_inbox if source_id.present?
  end

  private

  def generate_source_id
    case @inbox.channel_type
    when 'Channel::TwilioSms'
      twilio_source_id
    when 'Channel::Whatsapp'
      wa_source_id
    when 'Channel::Email'
      email_source_id
    when 'Channel::Sms'
      phone_source_id
    when 'Channel::Api', 'Channel::WebWidget'
      SecureRandom.uuid
    else
      raise "Unsupported operation for this channel: #{@inbox.channel_type}"
    end
  end

  def email_source_id
    raise ActionController::ParameterMissing, 'contact email' unless @contact.email

    @contact.email
  end

  def phone_source_id
    raise ActionController::ParameterMissing, 'contact phone number' unless @contact.phone_number

    @contact.phone_number
  end

  def wa_source_id
    raise ActionController::ParameterMissing, 'contact phone number' unless @contact.phone_number

    # whatsapp doesn't want the + in e164 format
    @contact.phone_number.delete('+').to_s
  end

  def twilio_source_id
    raise ActionController::ParameterMissing, 'contact phone number' unless @contact.phone_number

    case @inbox.channel.medium
    when 'sms'
      @contact.phone_number
    when 'whatsapp'
      "whatsapp:#{format_brazilian_cellphone(@contact.phone_number)}"
    end
  end

  def create_contact_inbox
    ::ContactInbox.create_with(hmac_verified: hmac_verified || false).find_or_create_by!(
      contact_id: @contact.id,
      inbox_id: @inbox.id,
      source_id: @source_id
    )
  end

  def format_brazilian_cellphone(number)
    digits = number.gsub(/\D/, "")

    if digits.match(/^55\d{10}$/)
      area_code = digits[2..3]
      phone_number = digits[4..-1]

      if phone_number.match(/^[6-9]/)
        phone_number = "9#{phone_number}"
      end

      return "+55#{area_code}#{phone_number}"
    end

    number
  end
end
