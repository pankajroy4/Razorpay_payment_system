class CreateRefunds < ActiveRecord::Migration[8.0]
  def change
    create_table :refunds do |t|
      t.references :payment, null: false, foreign_key: true
      t.integer :amount
      t.string :status
      t.string :razorpay_refund_id
      t.jsonb :raw_event

      t.timestamps
    end
  end
end
