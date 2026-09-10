class ProcessEventsController < ApplicationController
  def index
    render_page(ProcessEvent.order(occurred_at: :desc, id: :desc))
  end

  def create
    candidate = ProcessEvent.new(permitted_payload(:event_id, :process_name, :pid, :occurred_at))
    candidate.validate!
    existing = ProcessEvent.find_by(event_id: candidate.event_id)
    return render_existing(existing, candidate) if existing

    begin
      candidate.save!
      render json: { data: candidate.api_attributes }, status: :created
    rescue ActiveRecord::RecordNotUnique
      # The unique index also handles simultaneous deliveries of the same event.
      render_existing(ProcessEvent.find_by!(event_id: candidate.event_id), candidate)
    end
  end

  private

  def render_existing(existing, candidate)
    if existing.same_payload?(candidate)
      render json: { data: existing.api_attributes }, status: :ok
    else
      render_error(:conflict, "event_conflict", "Event ID was already used with a different payload.")
    end
  end
end
