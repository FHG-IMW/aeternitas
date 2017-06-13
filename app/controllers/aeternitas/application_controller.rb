module Aeternitas
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    def render_error(status, message)
      render file: 'aeternitas/error'
    end
  end
end
