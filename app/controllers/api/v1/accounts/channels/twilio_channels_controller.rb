class Api::V1::Accounts::Channels::TwilioChannelsController < Api::V1::Accounts::BaseController
  before_action :authorize_request

  def create
    process_create
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  private

  def authorize_request
    authorize ::Inbox
  end

  def process_create
    ActiveRecord::Base.transaction do
      authenticate_twilio
      build_inbox
      setup_webhooks if @twilio_channel.sms?
    end
  end

  def authenticate_twilio
    client = if permitted_params[:api_key_sid].present?
               Twilio::REST::Client.new(permitted_params[:api_key_sid], permitted_params[:auth_token], permitted_params[:account_sid])
             else
               Twilio::REST::Client.new(permitted_params[:account_sid], permitted_params[:auth_token])
             end
    client.messages.list(limit: 1)
  end

  def setup_webhooks
    ::Twilio::WebhookSetupService.new(inbox: @inbox).perform
  end

  def phone_number
    return if permitted_params[:phone_number].blank?

    medium == 'sms' ? permitted_params[:phone_number] : "whatsapp:#{format_brazilian_cellphone(permitted_params[:phone_number])}"
  end

  def medium
    permitted_params[:medium]
  end

  def build_inbox
    @twilio_channel = Current.account.twilio_sms.create!(
      account_sid: permitted_params[:account_sid],
      auth_token: permitted_params[:auth_token],
      api_key_sid: permitted_params[:api_key_sid],
      messaging_service_sid: permitted_params[:messaging_service_sid].presence,
      phone_number: phone_number,
      medium: medium
    )
    @inbox = Current.account.inboxes.create!(
      name: permitted_params[:name],
      channel: @twilio_channel
    )
  end

  def permitted_params
    params.require(:twilio_channel).permit(
      :account_id, :messaging_service_sid, :phone_number, :account_sid, :auth_token, :name, :medium, :api_key_sid
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
