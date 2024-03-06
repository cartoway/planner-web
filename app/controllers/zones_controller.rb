
class ZonesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_zone, only: [:show]
  around_action :includes_destinations, only: [:show]

  load_and_authorize_resource

  def show
    if params.key?(:destination_ids)
      destination_ids = params[:destination_ids].split(',')
      @destinations = current_user.customer.destinations.where(ParseIdsRefs.where(Destination, destination_ids))
    elsif params[:destinations] && ValueToBoolean.value_to_boolean(params[:destinations], true)
      @destinations = current_user.customer.destinations
    end
    respond_to do |format|
      format.excel do
        @customer = current_user.customer
        if !@destinations
          @destinations = @customer.destinations.includes_visits
        end
        @zones_destinations = []
        # TODO: Use postgis to compute included destinations
        @destinations&.each{ |destination|
          @zones_destinations << [destination, @zone.name] if @zone.inside_distance(destination.lat, destination.lng)
        }
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
            type: 'text/csv',
            filename: format_filename("#{t('activerecord.models.destinations.other')}-#{@zone.name || zone.id}") + '.csv',
            disposition: params.key?(:disposition) ? params[:disposition] : 'attachment'
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_zone
    @zoning = current_user.customer.zonings.includes(customer: [vehicle_usage_sets: [vehicle_usages: :vehicle]]).find(params[:zoning_id])
    @zone = @zoning.zones.find(params[:id] || params[:zone_id])
  end

  def includes_destinations
    Route.includes_destinations.scoping do
      yield
    end
  end
end
