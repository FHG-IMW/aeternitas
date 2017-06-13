class Patent < ApplicationRecord
  include Aeternitas::Pollable

  polling_options do
    polling_frequency :daily
  end
end
