class QuestionsController < ApplicationController

  def index
    @questions = user_questions
    @question = Question.new # for form
  end

  def create
    @question = Question.new(question_params)
    @question.session_id = session.id.to_s # Asocia la pregunta con la sesión actual
    if @question.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(:questions, partial: "questions/question",
            locals: { question: @question })
        end
        format.html { redirect_to questions_path }
      end
    else
      # render :index, status: :unprocessable_entity
      flash[:notice] = 'NO se puede'
      respond_to do |format|
        format.turbo_stream
      end
    end
  end

  private
  def user_questions
    Question.where(session_id: session.id.to_s)
  end



  def question_params
    params.require(:question).permit(:user_question)
  end
end
