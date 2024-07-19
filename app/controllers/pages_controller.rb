class PagesController < ApplicationController
  # skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @projects = Project.all
    @experiences = Experience.all
  end
end
