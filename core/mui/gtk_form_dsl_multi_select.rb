# -*- coding: utf-8 -*-
require 'mui/gtk_form_dsl_select'

class Gtk::FormDSL::MultiSelectBuilder < Gtk::FormDSL::SelectBuilder
  def build
    build_list
  end

private

  def build_check(value, text)
    check = Gtk::CheckButton.new text
    @formdsl[@config_key]&.include? value and check.active = true

    check.ssc :toggled do
      if check.active?
        @formdsl[@config_key] = (@formdsl[@config_key] || []) + [value]
      else
        @formdsl[@config_key] = @formdsl[@config_key] - [value]
      end
    end
    check
  end
end
