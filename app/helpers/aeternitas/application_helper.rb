module Aeternitas
  module ApplicationHelper
    def rate_ratio(ratio)
      label_type = case ratio
                when 0.0...0.01
                  "badge badge-success"
                when 0.01...0.1
                  "badge badge-warning"
                else
                  "badge badge-danger"
              end

      content_tag :span, "#{ratio * 100}%", class: label_type
    end

    def pretty_print_attributes(pollable)
      content_tag(:ul, class: "attribute-list") do
        pollable.attributes.map do |key, value|
          content_tag(:li) do
            (content_tag(:strong, "#{key}: ") + content_tag(:em, value)).html_safe
          end
        end.join("\n").html_safe
      end
    end
  end
end
