class ApplicationController < ActionController::API
  # Declared first so the more specific handlers below take precedence.
  # Every response, including an unexpected failure, uses the same JSON error envelope.
  rescue_from StandardError do |exception|
    Rails.logger.error { "#{exception.class}: #{exception.message}\n  #{Array(exception.backtrace).first(12).join("\n  ")}" }
    Rails.error.report(exception, handled: false)
    render_error(:internal_server_error, "internal_error", "The API could not complete this request.")
  end
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error(:bad_request, "invalid_json", "Request body must contain valid JSON.")
  end
  rescue_from ActionController::ParameterMissing, ActionController::BadRequest do
    render_error(:unprocessable_content, "invalid_input", "Request parameters are invalid.")
  end
  rescue_from ActiveRecord::RecordInvalid do |exception|
    render_error(:unprocessable_content, "invalid_input", exception.record.errors.full_messages.join(". "))
  end
  rescue_from Pagination::Invalid do
    render_error(:unprocessable_content, "invalid_input",
      "Use an integer limit from 1 to #{Pagination::MAX_LIMIT} and a nonnegative integer offset.")
  end

  def not_found
    render_error(:not_found, "not_found", "API route not found.")
  end

  private

  # Top-level scalar attributes only. Strong parameters would silently drop a
  # nested hash or array here; rejecting them keeps invalid payloads at 422.
  def permitted_payload(*keys)
    keys.each do |key|
      if params[key].is_a?(Array) || params[key].is_a?(ActionController::Parameters)
        raise ActionController::BadRequest
      end
    end
    params.permit(*keys)
  end

  def render_error(status, code, message, data: nil)
    body = { error: { code: code, message: message } }
    body[:data] = data if data
    render json: body, status: status
  end

  def render_page(scope)
    pagination = Pagination.new(params)
    records = scope.limit(pagination.limit).offset(pagination.offset)
    render json: {
      data: records.map(&:api_attributes),
      meta: { limit: pagination.limit, offset: pagination.offset, total: scope.count }
    }
  end
end
