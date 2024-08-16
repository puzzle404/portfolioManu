class CreateQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :questions do |t|
      t.text :user_question
      t.text :ai_answer
      t.string :session_id

      t.timestamps
    end
  end
end
