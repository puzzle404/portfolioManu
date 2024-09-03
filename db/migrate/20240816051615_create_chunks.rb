class CreateChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :chunks do |t|
      t.references :chunkable, polymorphic: true, null: false
      t.text :content
      t.vector :embedding, limit: 1536

      t.timestamps
    end
  end
end
