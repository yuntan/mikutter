# -*- coding: utf-8 -*-

require "gtk3"

require_relative 'toolbar_generator'

class Gtk::TabToolbar < Gtk::Grid
  def initialize(imaginally)
    type_strict imaginally => Plugin::GUI::TabToolbar
    @imaginally = imaginally
    super()
  end

  def set_button
    self.children.each(&method(:remove))
    Plugin::Gtk::ToolbarGenerator.generate(self,
                                           Plugin::GUI::Event.new(:tab_toolbar, @imaginally.parent, []),
                                           :tab)
  end
end
