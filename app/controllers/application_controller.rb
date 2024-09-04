class ApplicationController < ActionController::Base
  # before_action :authenticate_user!
  before_action :set_session

  def set_session
    unless session[:user_session_id]
      # Question.destroy_all
      session[:user_session_id] = session.id.to_s
    end
    puts 'SESSIONNNNNNNNNNNNNNNN'
    puts session[:user_session_id]
    puts session
    puts 'SESSIONNNNNNNNNNNNNNNN'

    return session[:user_session_id]
  end
end
