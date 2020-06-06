# frozen_string_literal: true

require_relative 'voter'

Plugin.create :subparts do
  defevent :subparts_widgets, prototype: [Diva::Model, Pluggaloid::COLLECT]
end
