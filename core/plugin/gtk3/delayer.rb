# -*- coding: utf-8 -*-

require 'glib2'

Module.new do

  def self.boot
    GLib::Idle.add do
      Delayer.run
      false
    end
  end

  Delayer.register_remain_hook do
    boot
  end

  boot
end
