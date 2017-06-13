module Aeternitas
  class WebUi < ::Rails::Engine
    isolate_namespace Aeternitas


    initializer "aeternitas.assets.precompile" do |app|
      app.config.assets.precompile += %w( aeternitas/aeternitas_web.js aeternitas/aeternitas_web.css )
    end
  end
end