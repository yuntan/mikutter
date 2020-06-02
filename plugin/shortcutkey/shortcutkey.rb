# -*- coding:utf-8 -*-
require_relative 'shortcutkey_listview'

Plugin.create :shortcutkey do

  filter_keypress do |key, widget, executed|
    type_strict key => String, widget => Plugin::GUI::Widget
    keybinds = (UserConfig[:shortcutkey_keybinds] || Hash.new)
    commands = lazy{ Plugin.filtering(:command, Hash.new).first }
    timeline = widget.is_a?(Plugin::GUI::Timeline) ? widget : widget.active_class_of(Plugin::GUI::Timeline)
    current_world, = Plugin.filtering(:world_current, nil)
    keybinds.values.lazy.select{|keyconf|
      keyconf[:key] == key
    }.select{|keyconf|
      role = commands.dig(keyconf[:slug], :role)
      role && widget.class.find_role_ancestor(role)
    }.map{|keyconf|
      [ commands[keyconf[:slug]],
        Plugin::GUI::Event.new(
          event: :contextmenu,
          widget: widget,
          messages: timeline ? timeline.selected_messages : [],
          world: world_by_uri(keyconf[:world]) || current_world
        )
      ]
    }.select{|command, event|
      command[:condition] === event
    }.each do |command, event|
      executed = true
      command[:exec].(event)
    end
    [key, widget, executed]
  end

  settings _("ショートカットキー") do
    listview = Plugin::Shortcutkey::ShortcutKeyListView.new(Plugin[:shortcutkey])
    listview.halign = :fill
    listview.hexpand = true

    filter_entry = listview.filter_entry = Gtk::Entry.new
    filter_entry.primary_icon_pixbuf = Skin[:search].pixbuf(width: 24, height: 24)
    filter_entry.ssc(:changed){
      listview.model.refilter
    }

    grid = Gtk::Grid.new
    grid.orientation = :vertical
    grid.row_spacing = 6
    grid << filter_entry << Gtk::Grid.new.tap do |grid|
      grid.valign = :fill
      grid.vexpand = true
      grid.column_spacing = 6
      grid << listview << listview.buttons(:vertical)
    end

    native grid
  end

  def world_by_uri(uri)
    Plugin.collect(:worlds).find{|w| w.uri.to_s == uri }
  end

end
