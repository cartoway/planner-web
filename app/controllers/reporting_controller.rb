class ReportingController < ApplicationController
  before_filter :authenticate_user!
  authorize_resource class: false

  def index; end

end
