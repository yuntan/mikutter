# -*- coding: utf-8 -*-

require 'mui/gtk_form_dsl'
require 'mui/gtk_form_dsl_multi_select'
require 'mui/gtk_form_dsl_select'

class Plugin::Extract::OptionWidget < Gtk::Grid
  include Gtk::FormDSL

  def create_inner_setting
    self.class.new(@plugin, @extract)
  end

  def initialize(plugin, extract)
    @plugin = plugin
    @extract = extract

    super()
    self.row_spacing = self.column_spacing = self.margin = 12
  end

  def [](key)
    case key
    when :icon, :sound
      @extract[key].to_s
    else
      @extract[key]
    end
  end

  def []=(key, value)
    case key
    when :icon, :sound
      @extract[key] = value.empty? ? nil : value
    else
      @extract[key] = value
    end
    @extract.notify_update
    value
  end

  def method_missing(method, *args, &block)
    @plugin.send(method, *args, &block)
  end
end
