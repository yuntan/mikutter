# frozen_string_literal: true

require_relative 'voter'
require_relative 'status'

Plugin.create :subparts do
  defevent :subparts_widgets, prototype: [Diva::Model, Pluggaloid::COLLECT]
end
