UserConfig[:gtk3_avatar_size] ||= 48
UserConfig[:gtk3_subparts_avatar_size] ||= 24

Plugin.create :gtk3 do
  settings _('表示') do
    select _('アバターアイコンのサイズ'), :gtk3_avatar_size do
      option 24, _('24 px')
      option 48, _('48 px')
    end
    select _('返信先・引用のアバターアイコンのサイズ'), :gtk3_subparts_avatar_size do
      option 18, _('18 px')
      option 24, _('24 px')
    end
  end
end
