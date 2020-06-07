# frozen_string_literal: true

require_relative 'photo'

Plugin.create :subparts_photo do
  psp = Plugin::SubpartsPhoto

  filter_subparts_widgets do |status, yielder|
    yielder << psp::Photo.new(status)
    [status, yielder]
  end

  settings _('タイムライン内画像表示') do

  end
end
