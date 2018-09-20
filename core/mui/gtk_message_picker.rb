# -*- coding: utf-8 -*-
require 'gtk3'
require_relative '../utils'
miquire :core, 'skin'
miquire :mui, 'mtk'
miquire :mui, 'extension'
miquire :mui, 'webicon'
miquire :miku, 'miku'

class Gtk::MessagePicker < Gtk::Frame
  DEFAULT_CONDITION = [:==, :user, ''.freeze].freeze

  def initialize(conditions, &block)
    conditions = [] unless conditions.is_a? MIKU::List
    super()
    @not = (conditions.respond_to?(:car) and (conditions.car == :not))
    if(@not)
      conditions = (conditions[1] or []).freeze end
    @changed_hook = block
    @function, *exprs = *conditions.to_a
    @function ||= :and

    self.border_width = 8
    self.label_widget = option_widgets

    shell = Gtk::Grid.new
    shell.orientation = :vertical
    @container = Gtk::Grid.new
    @container.orientation = :vertical
    @container.expand = true
    buttons = add_button
    buttons.halign = :center
    add(shell.add(@container).add(buttons))

    exprs.each{|x| add_condition(x) }
  end

  def function(new = @function)
    (new ? :or : :and) end

  def option_widgets
    @option_widgets ||= Gtk::Grid.new.
      add(Mtk::boolean(lambda{ |new|
                             unless new.nil?
                               @function = function(new)
                               call end
                             @function == :or },
                           'いずれかにマッチする')).
      add(Mtk::boolean(lambda{ |new|
                             unless new.nil?
                               @not = new
                               call end
                             @not },
                           '否定')) end

  def add_button
    @add_button ||= gen_add_button end

  def add_condition(expr = DEFAULT_CONDITION)
    pack = Gtk::Grid.new
    close = Gtk::Button.new.add(Gtk::WebIcon.new(Skin['close.png'], 16, 16)).set_relief(Gtk::RELIEF_NONE)
    close.valign = :start
    close.signal_connect(:clicked){
      @container.remove(pack)
      pack.destroy
      call
      false }
    pack.add(close)
    case expr.first
    when :and, :or, :not
      pack.add(Gtk::MessagePicker.new(expr, &method(:call)))
    else
      pack.add(Gtk::MessagePicker::PickCondition.new(expr, &method(:call))) end
    @container.add(pack) end

  def to_a
    result = [
      @function,
      *@container.children.map do |c| # c: Gtk::Grid
        c.children.select do |w| # w: Gtk::Widget
          (w.is_a?(Gtk::MessagePicker) ||
           w.is_a?(Gtk::MessagePicker::PickCondition))
        end.first.to_a
      end.reject(&:empty?)
    ].freeze
    if result.size == 1
      [].freeze
    else
      if @not
        result = [:not, result].freeze end
      result end end

  private

  def call
    if @changed_hook
      @changed_hook.call end end

  def gen_add_button
    container = Gtk::Grid.new
    btn = Gtk::Button.new('条件を追加')
    btn.signal_connect(:clicked){
      add_condition.show_all }
    btn2 = Gtk::Button.new('サブフィルタを追加')
    btn2.signal_connect(:clicked){
      add_condition([:and, DEFAULT_CONDITION]).show_all }
    container.add(btn).add(btn2) end

  class PickCondition < Gtk::Grid
    def initialize(conditions = DEFAULT_CONDITION, &block)
      super()
      @changed_hook = block
      @condition, @subject, @expr = *conditions.to_a
      build
    end

    def to_a
      [@condition, @subject, @expr].freeze end

    private

    def call
      if @changed_hook
        @changed_hook.call end end

    def build
      extract_condition = Hash[Plugin.filtering(:extract_condition, []).first.map{|ec| [ec.slug, ec]}]
      w_argument = Mtk::input(lambda{ |new|
                                unless new === nil
                                  @expr = new.freeze
                                  call end
                                @expr },
                              nil)
      w_operator = Mtk::chooseone(lambda{ |new|
                                    unless new === nil
                                      @condition = new.to_sym
                                      call end
                                    @condition.to_s },
                                  nil,
                                  Hash[Plugin.filtering(:extract_operator, []).first.map{ |eo| [eo.slug.to_s, eo.name] }])
      w_condition = Mtk::chooseone(lambda{ |new|
                                     unless new === nil
                                       @subject = new.to_sym
                                       call end
                                     sensitivity = extract_condition[@subject][:operator] && 0 != extract_condition[@subject][:args]
                                     w_argument.set_sensitive(sensitivity)
                                     w_operator.set_sensitive(sensitivity)
                                     @subject.to_s },
                                   nil,
                                   Hash[extract_condition.map{ |slug, ec| [slug.to_s, ec.name] }])
      add(w_condition)
      add(w_operator)
      add(w_argument)
    end
  end

end
