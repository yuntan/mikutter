# -*- coding: utf-8 -*-
# ウィンドウインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Window

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :window

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(slug, name)
    super
    Plugin.call(:window_created, self)
  end

  def self.active
    instance(:default, "デフォルト")
  end
end
