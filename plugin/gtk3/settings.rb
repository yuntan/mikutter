UserConfig[:gtk3_avatar_size] ||= 48
UserConfig[:gtk3_photo_size] ||= 96

Plugin.create :gtk3 do
  settings _('表示設定') do
    select _('アバターアイコンのサイズ'), :gtk3_avatar_size do
      option 24, _('24 px')
      option 48, _('48 px')
    end
    select _('画像のサイズ'), :gtk3_photo_height do
      option 48, _('48 px')
      option 96, _('96 px')
      option 144, _('144 px')
    end
  end
end
