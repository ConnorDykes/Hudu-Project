# Bounded offset pagination read from request parameters.
# Values must be plain decimal strings; arrays, nested hashes, signs, and decimals are rejected.
class Pagination
  class Invalid < StandardError; end

  DEFAULT_LIMIT = 30
  MAX_LIMIT = 100
  MAX_OFFSET = 9_223_372_036_854_775_807

  attr_reader :limit, :offset

  def initialize(params)
    @limit = integer(params, :limit, DEFAULT_LIMIT)
    @offset = integer(params, :offset, 0)
    raise Invalid unless (1..MAX_LIMIT).cover?(@limit) && @offset <= MAX_OFFSET
  end

  private

  def integer(params, key, default)
    return default unless params.key?(key)
    value = params[key]
    raise Invalid unless value.is_a?(String) && value.match?(/\A\d{1,19}\z/)
    value.to_i
  end
end
