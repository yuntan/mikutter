# -*- coding: utf-8 -*-

module Gtk::FormDSL
  class SelectBuilder
    # ==== Args
    # [label_text] ラベルテキスト
    # [config_key] 設定のキー
    def initialize(formdsl, label_text, config_key, values = {}, mode: :auto)
      @formdsl = formdsl
      @label_text = label_text
      @config_key = config_key
      @options = values.to_a
      @mode = mode
    end

    # セレクトボックスに要素を追加する
    # ==== Args
    # [value] 選択されたらセットされる値
    # [text] ラベルテキスト。 _&block_ がなければ使われる。
    # [&block] Plugin::Settings のインスタンス内で評価され、そのインスタンスが内容として使われる
    def option(value, text = nil, &block)
      @options ||= []
      @options << if block
                    grid = @formdsl.create_inner_setting
                    grid.instance_eval(&block)
                    label = grid.children.find { |w| w.is_a? Gtk::Label }
                    widget = grid.children.find { |w| !w.is_a? Gtk::Label }
                    grid.children.each { |w| grid.remove w }
                    [value, label.label, widget].freeze
                  else
                    [value, text].freeze
                  end
      self
    end

    # optionメソッドで追加された項目をウィジェットに組み立てる
    # ==== Return
    # Array[Gtk::Widget]
    def build
      if @mode == :auto && !widget?
        build_combo
      else
        build_list
      end
    end

    def method_missing(*args, &block)
      @formdsl.method_missing(*args, &block)
    end

  private

    def widget?
      @options.any? { |_, _, w| w }
    end

    def build_combo
      label = Gtk::Label.new @label_text
      combo = Gtk::ComboBoxText.new
      @options.each { |_, text| combo.append text, text }
      _, combo.active_id = @options.find { |value,| value == @formdsl[@config_key] }
      combo.ssc :changed do
        @formdsl[@config_key], = @options[combo.active]
      end

      [label, combo]
    end

    def build_list
      list = Gtk::ListBox.new
      list.hexpand = true
      list.selection_mode = :none
      list.set_header_func do |row, before|
        before.nil? or next
        row.header = Gtk::Label.new.tap do |w|
          w.markup = "<b>#{@label_text}</b>"
          w.margin = 6
          w.margin_start = 12
          w.halign = :start
        end
      end
      list.ssc :row_activated do |_, row|
        row.child.each do |w|
          if w.is_a? Gtk::CheckButton
            w.active = true
          else
            w.can_focus? and w.has_focus = true
          end
        end
      end

      @group = Gtk::RadioButton.new
      @options.each do |value, text, widget|
        # box = Gtk::Box.new :horizontal
        # box.margin = box.spacing = 12
        # 
        # label = Gtk::Label.new text
        # widget ||= build_button value
        # widget.hexpand = false
        # 
        # box.pack_start(label).pack_end(widget)

        check = build_check value, text
        check.halign = :start
        check.hexpand = true

        grid = Gtk::Grid.new
        grid.margin = grid.column_spacing = 12
        grid << check

        if widget
          widget.halign = :end
          grid << widget
        end

        list << grid
      end

      [Gtk::Frame.new << list]
    end

    def build_check(value, text)
      Gtk::RadioButton.new(label: text, member: @group).tap do |w|
        @formdsl[@config_key] == value and w.active = true
        w.ssc(:toggled) { w.active? and @formdsl[@config_key] = value }
      end
    end
  end
end
