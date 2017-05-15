# Configure Aeternitas
Aeternitas.configure do |config|
  config.redis = { url: 'localhost', port: 6379 } #this is the default Redis config which should work in most cases.
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Aeternitas::Sidekiq::Middleware
  end
end