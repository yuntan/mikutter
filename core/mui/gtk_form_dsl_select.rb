# -*- coding: utf-8 -*-
require 'mui/gtk_form_dsl'

# TODO: gtk3 rename to SelectBuilder
class Gtk::FormDSL::Select
  def initialize(formdsl, values=[])
    @formdsl = formdsl
    @options = values.to_a.freeze
  end

  # セレクトボックスに要素を追加する
  # ==== Args
  # [value] 選択されたらセットされる値
  # [label] ラベル。 _&block_ がなければ使われる。文字列。
  # [&block] Plugin::Settings のインスタンス内で評価され、そのインスタンスが内容として使われる
  def option(value, label = nil, &block)
    @options += if block_given?
                  widgets = @formdsl.instance_eval(&block)
                  widgets.each { |w| w.parent&.remove w }
                  [[value, label, widgets.last].freeze]
                else
                  [[value, label].freeze]
                end
    @options.freeze
    self
  end

  # optionメソッドで追加された項目をウィジェットに組み立てる
  # ==== Args
  # [text] ラベル。文字列。
  # [key] 設定のキー
  # ==== Return
  # Gtk::Frame
  def build(text, key)
    frame = Gtk::Frame.new

    list = Gtk::ListBox.new.apply do
      self.hexpand = true
      self.selection_mode = :none
      self.set_header_func do |row, before|
        before.nil? or next
        row.header = Gtk::Label.new.apply do
          self.markup = "<b>#{text}</b>"
          self.margin = 6
          self.margin_start = 12
          self.halign = :start
          self.hexpand = false
        end
      end
      ssc :row_activated do |_, row|
        row.child.each do |w|
          w.is_a? Gtk::RadioButton and (w.active = true)
          w.can_focus? and (w.has_focus = true)
        end
      end
    end

    radio = Gtk::RadioButton.new
    rows = @options.map do |value, text, widget|
      box = Gtk::Box.new :horizontal
      box.margin = box.spacing = 12

      label = Gtk::Label.new text
      widget ||= Gtk::RadioButton.new(member: radio).tap do |w|
        w.ssc(:toggled) { @formdsl[key] = value }
      end
      widget.hexpand = false

      box.pack_start(label).pack_end(widget)
    end
    rows.drop(1).reduce (list << rows.first) do |acc, row|
      acc << Gtk::Separator.new(:horizontal) << row
    end

    list.first do |row|
      row.child.any { |w| w.is_a? Gtk::Label && w.text == text }
    end&.activate

    frame << list
    frame
  end

  def method_missing(*args, &block)
    @formdsl.method_missing(*args, &block)
  end
end
