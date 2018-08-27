# -*- coding: utf-8 -*-
require "gtk3"

class Gtk::TabContainer < Gtk::Grid
  attr_reader :i_tab

  def initialize(tab)
    type_strict tab => Plugin::GUI::TabLike
    @i_tab = tab
    super()
    self.orientation = :vertical
  end

  def to_sym
    i_tab.slug end
  alias slug to_sym
end
