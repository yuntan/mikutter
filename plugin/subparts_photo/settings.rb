# frozen_string_literal: true

UserConfig[:subparts_photo_height] ||= 96

Plugin.create :subparts_photo do
  settings _('タイムライン内画像表示') do
    select _('画像の高さ'), :gtk3_photo_height do
      option 48, _('48 px')
      option 96, _('96 px')
      option 144, _('144 px')
    end
  end
end
