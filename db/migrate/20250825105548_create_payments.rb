class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.string :gateway
      t.integer :amount
      t.string :status
      t.string :receipt
      t.string :razorpay_order_id
      t.string :razorpay_payment_id
      t.jsonb :raw_event

      t.timestamps
    end
  end
end
