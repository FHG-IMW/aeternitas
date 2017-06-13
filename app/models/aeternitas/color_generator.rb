require 'colorable'

module Aeternitas
  class ColorGenerator
    def initialize(n, baseColor = "#C25B56")
      @counter = 0
      @base_color = Colorable::Color.new(baseColor).hsb
      @step = 240.0 / n
      @colors = []
    end

    def next
      generate_color(@counter)
      @counter += 1
      current
    end

    def current
      @colors[@counter] || generate_color(@counter)
    end


    def generate_color(i)
      next_hue = @base_color[0] + (@step * (i % 240.0))
      next_color = Colorable::Color.new(Colorable::HSB.new(next_hue, @base_color[1], @base_color[2]))
      @colors[i] = next_color
      next_color
    end
  end
end