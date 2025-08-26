class PaymentsController < ApplicationController
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :set_payment, only: [:show, :abandon]

  def index
    @payments = Payment.order(created_at: :desc).limit(50)
  end

  def new
  end

  # 1) Create order in Razorpay + DB record with status "created"
  def create
    amount_in_paise = (params[:amount].to_f * 100).to_i
    raise ActionController::BadRequest, "Amount must be > 0" if amount_in_paise <= 0

    receipt = "rcpt_#{SecureRandom.hex(6)}"

    order = Razorpay::Order.create(
      amount: amount_in_paise,
      currency: "INR",
      receipt: receipt
    )

    payment = Payment.create!(
      gateway: "razorpay",
      amount: amount_in_paise,
      status: "created",
      receipt: receipt,
      razorpay_order_id: order.id
    )

    render json: {
      order_id: order.id,
      key: Rails.application.credentials.dig(:razorpay, :key_id),
      amount: amount_in_paise,
      currency: "INR",
      payment_id: payment.id
    }
  rescue Razorpay::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
  end

  # 3) Webhook → update local DB based on Razorpay event
  def webhook
    payload = request.body.read
    signature = request.headers["X-Razorpay-Signature"]

    unless valid_webhook_signature?(payload, signature)
      render plain: "Signature mismatch", status: :unauthorized and return
    end

    event = JSON.parse(payload) rescue {}
    type = event["event"]

    case type
    when "payment.authorized", "payment.captured"
      handle_payment_event(event, "success") 
    when "payment.failed"
      handle_payment_event(event, "failed")
    when "refund.created"
      handle_refund_event(event, "created")
    when "refund.processed"
      handle_refund_event(event, "processed")
    when "refund.failed"
      handle_refund_event(event, "failed")
    else
      Rails.logger.info("Unhandled Razorpay webhook: #{type}")
    end

    head :ok
  end

  def abandon
    if @payment.status == "created"
      @payment.update(status: "abandoned")
    end
    render json: { success: true }, status: :ok
  end

  private

  def set_payment
    @payment = Payment.find(params[:id])
  end

  def valid_webhook_signature?(payload, signature)
    secret = Rails.application.credentials.dig(:razorpay, :webhook_secret)
    Razorpay::Utility.verify_webhook_signature(payload, signature, secret)
  rescue Razorpay::Errors::SignatureVerificationError
    false
  end

  # --- Helpers ---
  def handle_payment_event(event, status)
    payment_entity = event.dig("payload", "payment", "entity")
    return unless payment_entity

    local = Payment.find_by(razorpay_order_id: payment_entity["order_id"])
    return unless local

    local.update!(
      status: status,
      razorpay_payment_id: payment_entity["id"],
      raw_event: event
    )
  end

  def handle_refund_event(event, status)
    refund_entity = event.dig("payload", "refund", "entity")
    return unless refund_entity

    refund = Refund.find_by(razorpay_refund_id: refund_entity["id"])
    return unless refund

    refund.update!(
      status: status,
      raw_event: event
    )
  end
end
