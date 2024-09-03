class ChatbotJob < ApplicationJob
  queue_as :default

  def perform(question)
    puts "Starting job with args:"

    @question = question
    chatgpt_response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: questions_formatted_for_openai # to code as private method
      }
    )
    puts 'RESPUESTA AIIIIIIIIIIIIIIIIIIIII'
    new_content = chatgpt_response["choices"][0]["message"]["content"]
    puts 'RESPUESTA AIIIIIIIIIIIIIIIIIIIII'

    question.update(ai_answer: new_content)
    Turbo::StreamsChannel.broadcast_update_to(
      "question_#{@question.id}",
      target: "question_#{@question.id}",
      partial: "questions/question", locals: { question: question })

  end



  private

  def questions_formatted_for_openai
    questions = Question.where(session_id: @question.session_id)
    results = []

    system_text = "You are an assistant that provides detailed and accurate information about the portfolio and professional experiences of Manuel Ferrer.
    Manuel Ferrer is a skilled web developer with experience in Ruby on Rails, API development, and working with technologies such as Hotwire, Stimulus, and Turbo Streams.
    Your job is to answer questions based solely on his professional experiences, projects, and achievements."
    nearest_products = get_nearest_products # to code as private method
    nearest_products.each do |product|
      system_text += "Description: #{product.content}, All the information is about experience and projects that Manuel Ferrer has"
    end
    results << { role: "system", content: system_text }

    questions.each do |question|
      results << { role: "user", content: question.user_question }
      results << { role: "assistant", content: question.ai_answer || "" }
    end

    return results
  end

  def get_nearest_products
    response = client.embeddings(
      parameters: {
        model: 'text-embedding-3-small',
        input: @question.user_question
      }
    )
    question_embedding = response['data'][0]['embedding']
    nearest_products = Chunk.nearest_neighbors(
      :embedding, question_embedding,
      distance: "euclidean"
    ) # you may want to add .first(3) here to limit the number of results
    nearest_products.each do |n|
      puts 'CHUNKSSSSS'
      puts n.content
      # n.content
    end
    return nearest_products
  end

  def client
    @client ||= OpenAI::Client.new
  end

end
