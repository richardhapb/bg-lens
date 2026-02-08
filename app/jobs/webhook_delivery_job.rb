class WebhookDeliveryJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(delivery_id)
    delivery = WebhookDelivery.pending.find_by(id: delivery_id)
    return unless delivery

    report = delivery.report

    payload = build_payload(report)

    response = HTTParty.post(
      delivery.url,
      body: payload.to_json,
      headers: {
        "Content-Type" => "application/json",
        "X-Webhook-Signature" => generate_signature(payload)
      },
      timeout: 10
    )

    if response.success?
      delivery.update!(status: "delivered", payload: payload)
    else
      handle_failure(delivery, "HTTP #{response.code}: #{response.message}")
    end
  rescue HTTParty::Error, Timeout::Error, SocketError => e
    handle_failure(delivery, e.message)
    raise
  end

  private

  def build_payload(report)
    {
      report_id: report.id,
      status: report.status,
      completed_at: report.completed_at&.iso8601,
      candidate: {
        name: report.candidate.name,
        email: report.candidate.email
      },
      checks: report.checks.map do |check|
        {
          type: check.check_type,
          status: check.status,
          result: check.result
        }
      end
    }
  end

  def generate_signature(payload)
    # In production, use a secret key from credentials
    secret = Rails.application.secret_key_base || "development-secret"
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload.to_json)
  end

  def handle_failure(delivery, message)
    delivery.increment!(:attempts)
    if delivery.attempts >= 5
      delivery.update!(status: "failed")
      Rails.logger.error "Webhook delivery #{delivery.id} permanently failed: #{message}"
    else
      Rails.logger.warn "Webhook delivery #{delivery.id} attempt #{delivery.attempts} failed: #{message}"
    end
  end
end
