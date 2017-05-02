# Configure Aeternitas
Aeternitas.configure do |config|
  # config goes here...
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Aeternitas::Sidekiq::Middleware
  end
end