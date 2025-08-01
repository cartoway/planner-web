header = []
if params[:planning_id]
  header << I18n.t('order_arrays.export_file.vehicle')
end
header += [
    I18n.t('order_arrays.export_file.name'),
    I18n.t('order_arrays.export_file.comment')
] + @order_array.days.times.collect { |i|
  l @order_array.base_date + i
} + @order_array.customer.products.collect(&:code) + [
  I18n.t('order_arrays.export_file.total')
]
csv << header

sum_column = Hash.new { |h,k| h[k] = {} }
@visits_orders.collect { |visit_orders, vehicle_usage|
  sum = {}
  total = 0
  line = []
  if params[:planning_id]
    line << (vehicle_usage.nil? ? '' : vehicle_usage.vehicle.name)
  end
  line += [
    visit_orders[0].visit.destination.name,
    visit_orders[0].visit.destination.comment
  ] + visit_orders.collect { |order|
    order.products.each { |product|
      sum_column[order.shift][product] = (sum_column[order.shift][product] || 0) + 1
      sum[product] = (sum[product] || 0 ) + 1
    }
    order.products.collect(&:code).join('/')
  } + @order_array.customer.products.collect{ |product|
    total += sum[product] || 0
    sum[product]
  } + [
    total > 0 ? total : nil
  ]
  csv << line
}

total_column = []
grand_total = Hash.new { |h,k| h[k] = 0 }
shift = 0
@order_array.customer.products.each { |product|
  csv << [
    product.code,
    product.name
  ] + @order_array.days.times.collect { |i|
    total_column[i] = sum_column[i][product] ? (total_column[i] || 0) + sum_column[i][product] : total_column[i]
    grand_total[product] += sum_column[i][product] || 0
    sum_column[i][product]
  } + [nil] * shift + [grand_total[product] > 0 ? grand_total[product] : nil]
  shift += 1
}

csv << [
  I18n.t('order_arrays.export_file.total'),
  nil
] + @order_array.days.times.collect { |i|
  total_column[i]
} + [nil] * @order_array.customer.products.size + [grand_total.values.sum]
