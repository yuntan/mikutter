# -*- coding: utf-8 -*-
# なーにがkonami_watcherじゃ

module Gtk
  KONAMI_SEQUENCE = [Gdk::Keyval::KEY_Up,
                     Gdk::Keyval::KEY_Up,
                     Gdk::Keyval::KEY_Down,
                     Gdk::Keyval::KEY_Down,
                     Gdk::Keyval::KEY_Left,
                     Gdk::Keyval::KEY_Right,
                     Gdk::Keyval::KEY_Left,
                     Gdk::Keyval::KEY_Right,
                     Gdk::Keyval::KEY_b,
                     Gdk::Keyval::KEY_a].freeze
  remain = KONAMI_SEQUENCE
  # TODO: gtk3 key_snooper_installの代替方法を考える
  # Gtk.key_snooper_install do |grab_widget, event|
  #   if Gdk::Event::KEY_PRESS == event.event_type
  #     if remain.first == event.keyval
  #       remain = remain.cdr
  #       unless remain
  #         Plugin.call :konami_activate
  #         remain = KONAMI_SEQUENCE
  #       end
  #     else
  #       remain = KONAMI_SEQUENCE
  #     end
  #   end
  #   false
  # end
end
