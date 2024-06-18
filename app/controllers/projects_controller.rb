class ProjectsController < ApplicationController
  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    skill_ids = params[:project][:skill_ids].compact.reject { |element| element.strip.empty? }
    @project.save!
  end

  def edit
    @project = Project.find(params[:id])
  end

  def destroy
  end

  def update
  end

  def project_params
    params.require(:project).permit(:name, :description, :short_description, :start_date, :end_date, photos: [], skill_ids: [])
  end
end
