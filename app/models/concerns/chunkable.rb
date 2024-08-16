module Chunkable
  include ActiveSupport::Concern

  def chunk!
    # Delete existing chunks
    chunks.destroy_all
    # Create new chunk
    Langchain::Chunker::RecursiveText.new(
      chunkable_s,
      chunk_size: 1535,
      chunk_overlap: 200,
      separators: chunkable_separators
    ).chunks.each do |chunk|
        content = chunk.text
        openai_client = OpenAI::Client.new
        response = openai_client.embeddings(
          parameters: {
            model: 'text-embedding-ada-002',
            input: content
          }
        )
      embedding = response.dig('data', 0, 'embedding')
      chunks.create!(
        content: content,
        embedding: embedding
      )

    end
    puts "#{chunks.count} chunks created for #{self.class.name} #{id}"
  end

  def open_ai
    Langchain::LLM::OpenAI.new(api_key: ENV.fetch("OPENAI_ACCESS_TOKEN"))
  end
end
