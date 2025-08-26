class RefundsController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    payment = Payment.find(params[:payment_id])

    unless payment.status == "success" && payment.razorpay_payment_id.present?
      return render json: { error: "Payment not refundable" }, status: :unprocessable_entity
    end

    # Check for already processed refunds
    if payment.refunds.where(status: "processed").exists?
      return render json: { error: "Payment has already been refunded" }, status: :unprocessable_entity
    end

    amount_in_paise = (params[:amount].presence || payment.amount / 100.0).to_f * 100
    amount_in_paise = amount_in_paise.to_i

    # 1) Create a local Refund record with status = "initiated"
    refund_record = payment.refunds.create!(
      amount: amount_in_paise,
      status: "initiated"
    )

    begin
      # 2) Call Razorpay Refund API
      client = Razorpay::Payment.fetch(payment.razorpay_payment_id)
      refund = client.refund(amount: refund_record.amount)

      # 3) Update Refund record with Razorpay response
      refund_record.update!(
        razorpay_refund_id: refund.id,
        status: refund.status,
        raw_event: refund.attributes
      )
    rescue Razorpay::Error => e
      refund_record.update!(status: "failed", raw_event: { error: e.message })
      return render json: { error: e.message }, status: :unprocessable_entity
    end

    render json: { refund_id: refund_record.id, status: refund_record.status }
  end
end
