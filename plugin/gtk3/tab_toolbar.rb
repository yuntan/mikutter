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
    current_world, = Plugin.filtering(:world_current, nil)
    Plugin::Gtk::ToolbarGenerator.generate(
      self,
      Plugin::GUI::Event.new(
        event: :tab_toolbar,
        widget: @imaginally.parent,
        messages: [],
        world: current_world
      ),
      :tab)
  end
end
