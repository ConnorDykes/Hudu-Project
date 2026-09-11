# Rack response formatter called by ActionDispatch::ShowExceptions. Avoid
# controller dispatch here: the original request may have malformed parameters.
# Rails owns exception logging/reporting and the decision to render or re-raise.
class ApiExceptions
  def self.call(env)
    status = env.fetch("PATH_INFO").delete_prefix("/").to_i
    code, message = case status
    when 400
      [ "invalid_input", "Request parameters are malformed." ]
    when 404
      [ "not_found", "API route not found." ]
    when 406
      [ "not_acceptable", "The requested response format is not supported." ]
    when 422
      [ "invalid_input", "Request parameters are invalid." ]
    when 500..599
      [ "internal_error", "The API could not complete this request." ]
    else
      [ "request_error", Rack::Utils::HTTP_STATUS_CODES.fetch(status) ]
    end

    body = { error: { code: code, message: message } }.to_json
    headers = { "content-type" => "application/json; charset=utf-8", "content-length" => body.bytesize.to_s }
    head_request = env["action_dispatch.original_request_method"] == "HEAD"
    [ status, headers, head_request ? [] : [ body ] ]
  end
end
