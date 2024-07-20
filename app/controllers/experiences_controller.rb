class ExperiencesController < ApplicationController
  before_action :find_experience, only: [:edit, :update]
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
    if params[:experience][:photos].blank? || params[:experience][:photos] == [""]
      params = experience_params.except(:photos)
    else
      params = experience_params
    end
    if @experience.update(params)
      redirect_to root_path, notice: 'Todo Ok'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def remove_photo

  end

  def delete
  end

  private

  def find_experience
    @experience = Experience.find(params[:id])
  end

  def experience_params
    params.require(:experience).permit(:id, :name, :description, :start_date, :end_date, :role, :created_at, :company, :updated_at, :short_description, photos: [], skill_ids: [])
  end
end
