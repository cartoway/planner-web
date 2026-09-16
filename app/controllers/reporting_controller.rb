class ReportingController < ApplicationController
  include V2Layout
  before_action :authenticate_user!
  authorize_resource class: false

  def index
    render_v2_page 'v2/reporting/index' if layout_v2?
  end
end
