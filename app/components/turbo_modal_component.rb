# frozen_string_literal: true

include Turbo::FramesHelper

class TurboModalComponent < ViewComponent::Base
  def initialize(params)
    super
    @title = params[:title]
    @clases= params[:clases]
    @modal_h= params[:modal_h]
    @modal_b=params[:modal_b]
    @modal_f=params[:modal_f]
    @modal_dialog=params[:modal_d]
  end
end
