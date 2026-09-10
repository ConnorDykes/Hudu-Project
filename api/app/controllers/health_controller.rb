class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") }
    render json: { status: "ok" }
  rescue ActiveRecord::ActiveRecordError
    render_error(:service_unavailable, "database_unavailable", "Database is unavailable.")
  end
end
