# -*- coding: utf-8 -*-
#
require 'pathname'

module Plugin::Settings; end

require_relative 'basic_settings'
require_relative 'menu'

Plugin.create(:settings) do

  command(:open_setting,
          name: _('設定'),
          condition: lambda{ |opt| true },
          visible: true,
          icon: Skin['settings.png'],
          role: :window) do |opt|
    Plugin.call(:open_setting)
  end

  on_open_setting do
    setting_window.show_all end

  def setting_window
    return @window if defined?(@window) and @window
    builder = Gtk::Builder.new
    s = (Pathname(__FILE__).dirname / 'settings.glade').to_s
    builder.add_from_file s
    @window = builder.get_object 'window'
    rect = { width: 256, height: 256 }
    @window.icon = Skin['settings.png'].load_pixbuf(**rect) do |pb|
      @window.destroyed? or @window.icon = pb
    end
    settings = builder.get_object 'settings'
    scrolled_menu = builder.get_object 'scrolled_menu'
    menu = Plugin::Settings::Menu.new
    scrolled_menu.add_with_viewport menu

    menu.ssc(:cursor_changed) do
      if menu.selection.selected
        active_iter = menu.selection.selected
        if active_iter
          settings.hide
          settings.children.each(&settings.method(:remove))
          settings.add(active_iter[Plugin::Settings::Menu::COL_RECORD].widget).show_all
        end
      end
      false
    end

    @window.ssc(:destroy) {
      @window = nil
      false
    }

    @window
  end
end
