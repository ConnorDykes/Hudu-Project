class Pagination
  class Invalid < StandardError; end

  attr_reader :limit, :offset

  def initialize(values, raw: values)
    @limit = integer(values, raw, "limit", 30)
    @offset = integer(values, raw, "offset", 0)
    raise Invalid unless (1..100).cover?(@limit) && (0..9_223_372_036_854_775_807).cover?(@offset)
  end

  private

  def integer(values, raw, key, default)
    return default unless raw.key?(key)
    value = values[key]
    raise Invalid unless value.is_a?(String) && value.match?(/\A\d{1,19}\z/)
    value.to_i
  end
end
