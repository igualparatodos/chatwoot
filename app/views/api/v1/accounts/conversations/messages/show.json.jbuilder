json.payload do
  json.partial! 'api/v1/models/message', formats: [:json], message: @message
end

