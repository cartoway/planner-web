module EmailHelper
  def email_image_tag(image, **options)
    image_name = image
    if image.start_with?('/uploads')
      image_name = image.split('/').last
      attachments[image_name] = File.read(Rails.root.join("public/#{image}")) if attachments[image_name].nil?
    else
      attachments[image_name] = File.read(Rails.root.join("app/assets/images/#{image}")) if attachments[image_name].nil?
    end

    image_tag attachments[image_name].url, **options
  end

  def base64_image(image, **options)
    image = image.start_with?('/uploads') ? ("public/" + image) : ("app/assets/images/" + image)
    imageB64 = Base64.encode64 File.read(Rails.root.join(image))

    image_tag "data:image/png;base64,#{imageB64}", **options
  end

  def reseller_logo_path(reseller)
    url = "#{reseller.url_protocol}://#{reseller.host}"
    if reseller.logo_small.url
      url += reseller.logo_small.url
    elsif reseller.logo_large.url
      url += reseller.logo_large.url
    else
      url += '/assets/logo.png'
    end
    url
  end

  def network_icon_url(image_name)
    Rails.application.config.automation[:network_icons][image_name]
  end

  def panel_url_for(mail_type, panel_name)
    Rails.application.config.automation[:parameters][mail_type][:image_links][panel_name]
  end
end
