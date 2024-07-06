class ProjectsController < ApplicationController
  before_action :project_find, only: [:edit, :show]
  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    skill_ids = params[:project][:skill_ids].compact.reject { |element| element.strip.empty? }
    if @project.save
      redirect_to root_path, notice: "todo OK"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def destroy
  end

  def update
    @project = Project.find(params[:id])

    skill_ids = params[:project][:skill_ids].compact.reject { |element| element.strip.empty? }
    if @project.update(project_params)
      redirect_to project_path(params[:id]), notice: "todo OK"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def project_params
    params.require(:project).permit(:name, :description, :short_description, :start_date, :end_date, photos: [], skill_ids: [])
  end

  def project_find
    @project = Project.find(params[:id])
  end
end
