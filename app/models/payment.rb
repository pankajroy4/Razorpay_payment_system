# app/models/payment.rb
class Payment < ApplicationRecord
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :gateway, presence: true
  has_many :refunds

  def inr
    (amount.to_i / 100.0).round(2)
  end
end
