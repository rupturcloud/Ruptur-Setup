# Aplicado após db:chatwoot_prepare. As configurações são persistidas usando o
# modelo da aplicação, que mantém o formato serializado e os callbacks de cache.
values = {
  'INSTALLATION_NAME' => ENV.fetch('RUPTUR_CHAT_BRAND'),
  'BRAND_NAME' => ENV.fetch('RUPTUR_CHAT_BRAND'),
  'BRAND_URL' => ENV.fetch('RUPTUR_BRAND_URL'),
  'WIDGET_BRAND_URL' => ENV.fetch('RUPTUR_BRAND_URL'),
  'MAILER_SUPPORT_EMAIL' => ENV.fetch('RUPTUR_SUPPORT_EMAIL')
}
InstallationConfig.transaction do
  values.each do |name, value|
    config = InstallationConfig.find_or_initialize_by(name: name)
    config.value = value
    config.locked = false
    config.save!
  end
end
puts 'Configurações de marca atualizadas.'
