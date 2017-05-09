# Configure Aeternitas
Aeternitas.configure do |config|
  # config goes here...
  config.redis = { url: 'localhost', port: 6379 }
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Aeternitas::Sidekiq::Middleware
  end
end