# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_message_base'

UserConfig[:reply_present_policy] ||= %i<header icon>
UserConfig[:reply_edge] ||= :floating

class Gdk::ReplyViewer < Gdk::SubPartsMessageBase
  register

  attr_reader :messages

  def initialize(*args)
    super
    if helper.message.has_receive_message?
      helper.message.replyto_source_d(true).next{ |reply|
        @messages = Messages.new([reply]).freeze
        render_messages
      }.terminate('リプライ描画中にエラーが発生しました') end end

  def badge(_message)
    Gdk::Pixbuf.new(Skin.get('reply.png'), @badge_radius*2, @badge_radius*2) end

  def background_color(message)
    color = Plugin.filtering(:subparts_replyviewer_background_color, message, nil).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      [1.0]*3 end end

  def main_text_color(message)
    UserConfig[:reply_text_color].map{ |c| c.to_f / 65536 } end

  def main_text_font(message)
    Pango::FontDescription.new(UserConfig[:reply_text_font]) end

  def header_left_content(*args)
    if show_header?
      super end end

  def header_right_content(*args)
    if show_header?
      super end end

  def icon_size
    if show_icon?
      if UserConfig[:reply_icon_size]
        Gdk::Rectangle.new(0, 0, UserConfig[:reply_icon_size], UserConfig[:reply_icon_size])
      else
        super end end end

  def text_max_line_count(message)
    UserConfig[:reply_text_max_line_count] || super end

  def render_outline(message, context, base_y)
    unless show_edge?
      @edge = 2
      return end
    @edge = 8
    case UserConfig[:reply_edge]
    when :floating
      render_outline_floating(message, context, base_y)
    when :solid
      render_outline_solid(message, context, base_y)
    when :flat
      render_outline_flat(message, context, base_y) end end

  def render_badge(message, context)
    return unless show_edge?
    case UserConfig[:reply_edge]
    when :floating
      render_badge_floating(message, context)
    when :solid
      render_badge_solid(message, context)
    when :flat
      render_badge_flat(message, context) end end

  def show_header?
    (UserConfig[:reply_present_policy] || []).include?(:header) end

  def show_icon?
    (UserConfig[:reply_present_policy] || []).include?(:icon) end

  def show_edge?
    (UserConfig[:reply_present_policy] || []).include?(:edge) end
end
