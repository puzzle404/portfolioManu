class ExperiencesController < ApplicationController
  def new
    @experience = Experience.new
  end

  def create
    @experience = Experience.new(experience_params)
    if @experience.save
      redirect_to root_path, notice: 'Todo Ok'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
  end

  private

  def find_experience
    @experience - Experience.find(params[:id])
  end

  def experience_params
    params.require(:experience).permit(:id, :name, :description, :start_date, :end_date, :role, :created_at, :updated_at, :short_description, photos: [], skill_ids: [])
  end
end
