class V2::Entities::StopStatus < Grape::Entity
  def self.entity_name
    'V2_StopStatus'
  end

  expose(:id, documentation: { type: Integer })
  expose(:index, documentation: { type: Integer, desc: 'Stop\'s Index' })
  expose(:status, documentation: { type: String, desc: 'Status of stop.' }) { |stop| stop.status && I18n.t('plannings.edit.stop_status.' + stop.status.downcase, default: stop.status) }
  expose(:status_code, documentation: { type: String, desc: 'Status code of stop.' }) { |stop| stop.status && stop.status.downcase }
  expose(:eta, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device.' })
  expose(:eta_formated, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device.' }) { |stop| stop.eta && I18n.l(stop.eta, format: :hour_minute) }
end
