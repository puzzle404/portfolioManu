module Finance
  class BaseController < ApplicationController
    before_action :authenticate_user!
    layout "finance"
  end
end
