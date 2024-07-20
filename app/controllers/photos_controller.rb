class PhotosController < ApplicationController
  def destroy
    @experience = Experience.find(params[:experience_id])
    @photo = @experience.photos.find(params[:id])
    begin
      @photo.purge
      @removed = true
      flash[:notice] = 'Photo deleted successfully'
    rescue => e
      flash[:alert] = 'Photo could not be deleted'
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  # def find_experience
  #   @experience = Experience.find(params[:id])
  # end

  # def experience_params
  #   params.require(:experience).permit(:id, :name, :description, :start_date, :end_date, :role, :created_at, :company, :updated_at, :short_description, photos: [], skill_ids: [])
  # end
end
