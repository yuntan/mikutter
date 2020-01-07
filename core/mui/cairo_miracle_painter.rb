# -*- coding: utf-8 -*-

require 'gtk3'
require 'cairo'

# TODO: gtk3 remove
# require 'mui/cairo_coordinate_module'
require 'mui/cairo_icon_over_button'
require 'mui/cairo_textselector'
require 'mui/cairo_sub_parts_helper'
require 'mui/cairo_replyviewer'
require 'mui/cairo_sub_parts_favorite'
require 'mui/cairo_sub_parts_share'
require 'mui/cairo_sub_parts_quote'
require 'mui/cairo_markup_generator'
require 'mui/cairo_special_edge'
require 'mui/gtk_photo_pixbuf'

# Modelを表示するためのWidget。名前は言いたかっただけ。クラス名まで全てはつね色に染めて♪
class Gdk::MiraclePainter < Gtk::Widget
=begin rdoc
  * カスタムwidgetの実装
    https://developer.gnome.org/gtkmm-tutorial/stable/sec-custom-widgets.html.en
  * height-for-widthの実装
    https://developer.gnome.org/gtk3/stable/GtkWidget.html#GtkWidget.description
=end

  # TODO: gtk3 separete Rect class to another file
  class Rect
    extend Memoist
    attr_reader :x, :y, :width, :height

    def initialize(x, y, width, height)
      @x, @y, @width, @height = x, y, width, height
    end

    def point_in?(x, y)
      left <= x and x <= right and top <= y and y <= bottom
    end

    def bottom
      y + height end

    def right
      x + width end

    alias :left :x
    alias :top :y
  end

  ICON_SIZE = [48, 48].freeze # [width, height]
  MARGIN = 2 # margin for icon, etc
  SPACING = 2 # spacing between mainparts and subparts
  DEPTH = Gdk::Visual.system.depth # color depth
  # TODO: gtk3 VERBOSE off
  VERBOSE = true # for debug

  extend Gem::Deprecate

  type_register

  signal_new(:clicked, GLib::Signal::RUN_FIRST, nil, nil, Gdk::EventButton)

  # TODO: gtk3 remove
  # signal_new(:modified, GLib::Signal::RUN_FIRST, nil, nil)
  # signal_new(:expose_event, GLib::Signal::RUN_FIRST, nil, nil)

  # TODO: gtk3 remove
  # include Gdk::Coordinate
  include Gdk::IconOverButton
  include Gdk::TextSelector
  include Gdk::SubPartsHelper
  include Gdk::MarkupGenerator

  # TODO: gtk3 remove
  # EMPTY = Set.new.freeze
  # Event = Struct.new(:event, :message, :timeline, :miraclepainter)
  WHITE = ([0xffff]*3).freeze
  BLACK = [0, 0, 0].freeze
  NUMERONYM_MATCHER = /[a-zA-Z]{4,}/.freeze
  NUMERONYM_CONVERTER = ->(r) { "#{r[0]}#{r.size-2}#{r[-1]}" }

  # TODO: gtk3 remove
  # attr_reader :message, :p_message, :tree, :selected
  attr_reader :model, :selected
  alias message model
  # TODO: gtk3 deprecate :message
  deprecate :message, :model, 2019, 10

  # TODO: gtk3 adjust size
  WIDTH_MIN = 100 # minimum width
  WIDTH_NAT = 250 # natural width

=begin
  @@miracle_painters = Hash.new

  # _message_ を内部に持っているGdk::MiraclePainterの集合をSetで返す。
  # ログ数によってはかなり重い処理なので注意
  def self.findbymessage(message)
    result = Set.new
    Gtk::TimeLine.timelines.each{ |tl|
      found = tl.get_record_by_message(message)
      result << found.miracle_painter if found }
    result.freeze
  end

  # findbymessage のdeferred版。
  def self.findbymessage_d(message)
    result = Set.new
    Gtk::TimeLine.timelines.deach{ |tl|
      if not tl.destroyed?
        found = tl.get_record_by_message(message)
        result << found.miracle_painter if found end
    }.next{
      result.freeze }
  end

  def self.mp_modifier
    @mp_modifier ||= lambda { |miracle_painter|
      if (not miracle_painter.destroyed?) and (not miracle_painter.tree.destroyed?)
        miracle_painter.tree.model.each{ |model, path, iter|
          if iter[0] == miracle_painter.message.uri.to_s
            miracle_painter.tree.queue_draw
            break end } end
      false } end
=end

  class << self
    def init
      self.css_name = 'miraclepainter'
    end
  end

  def initialize(model)
    super()

    @model = model

    # This widget create _Gdk::Window_ itself on _realize_.
    self.has_window = true
    self.redraw_on_allocate = true
  end

  # :nodoc:
  memoize def score
    Plugin[:gtk3].score_of(model)
  end

  # virtual function overrides
  if true # rubocop:disable Lint/LiteralAsCondition
    # override virtual function Gtk::Widget#request_mode
    def request_mode
      notice 'MiraclePainter#request_mode' if VERBOSE

      Gtk::SizeRequestMode::HEIGHT_FOR_WIDTH
    end

    # override virtual function Gtk::Widget#preferred_width
    def preferred_width
      notice 'MiraclePainter#preferred_width' if VERBOSE

      [WIDTH_MIN, WIDTH_NAT]
    end

    # override virtual function Gtk::Widget#preferred_height_for_width
    def preferred_height_for_width(width)
      notice 'MiraclePainter#preferred_height_for_width(' \
        "width = #{width})" if VERBOSE

      @width = width
      height = mainpart_height + SPACING + subparts_height
      [height, height] # minimum, natural
    end
  end

  # sockets
  if true # rubocop:disable Lint/LiteralAsCondition
=begin
  signalの発行順序
  size_allocate > realize > draw
=end

    # リサイズ時に呼ばれる
    def signal_do_size_allocate(rect)
      notice 'MiraclePainter*size_allocate(' \
        "rect = {x: #{rect.x}, y: #{rect.y}, width: #{rect.width}, " \
        "height: #{rect.height}})" if VERBOSE

      @width = rect.width
      # TODO gobject-introspectionでvirtual methodをoverride出来るようになったら
      # 下の一行を消す
      set_size_request(-1, mainpart_height + SPACING + subparts_height)
      self.allocation = rect
      window.move_resize rect.x, rect.y, rect.width, rect.height if window
    end

    def signal_do_realize
      notice 'MiraclePainter*realize' if VERBOSE

      w, h = allocation.width, allocation.height
      attr = (Gdk::WindowAttr.new w, h, :input_output, :child).tap do |attr|
        attr.x = allocation.x
        attr.y = allocation.y
        attr.visual = visual
        # attr.event_mask = events | Gdk::EventMask::EXPOSURE_MASK
        em = Gdk::EventMask
        attr.event_mask = em::BUTTON_PRESS_MASK |
                          em::BUTTON_RELEASE_MASK |
                          em::POINTER_MOTION_MASK |
                          em::LEAVE_NOTIFY_MASK |
                          em::FOCUS_CHANGE_MASK
      end

      wat = Gdk::WindowAttributesType
      mask = wat::X | wat::Y | wat::VISUAL
      window = Gdk::Window.new parent_window, attr, mask

      self.window = window
      register_window window
      self.realized = true
    end

    def signal_do_unrealize
      notice 'MiraclePainter*unrealize' if VERBOSE

      unregister_window window
      window.destroy
      self.realized = false
    end

    def signal_do_draw(ctx)
      notice 'MiraclePainter*draw(ctx)' if VERBOSE

      render_to_context ctx
      true # stop propagation
    end

    def signal_do_clicked(ev)
      notice 'MiraclePainter*clicked(ev)' if VERBOSE

      x, y = ev.x, ev.y
      case ev.button
      when 1
        iob_clicked(x, y)
        if not textselector_range
          index = main_pos_to_index(x, y)
          if index
            clicked_note = score.find{|note|
              index -= note.description.size
              index <= 0
            }
            Plugin.call(:open, clicked_note) if clickable?(clicked_note)
          end
        end
      when 3
        # @tree.get_ancestor(Gtk::Window).set_focus(@tree)
        Plugin::GUI::Command.menu_pop
      end
    end

    def signal_do_button_press_event(ev)
      notice 'MiraclePainter*button_press_event(ev)' if VERBOSE

      return false if ev.button != 1
      textselector_press(*main_pos_to_index_forclick(ev.x, ev.y)[1..2])
      true # stop propagation
    end

    def signal_do_button_release_event(ev)
      notice 'MiraclePainter*button_release_event(ev)' if VERBOSE

      return false if ev.button != 1
      x, y = ev.x, ev.y
      textselector_release(*main_pos_to_index_forclick(x, y)[1..2])
      true # stop propagation
    end

    def signal_do_motion_notify_event(ev)
      notice 'MiraclePainter*motion_notify_event(ev)' if VERBOSE

      x, y = ev.x, ev.y
      point_moved_main_icon(x, y)
      textselector_select(*main_pos_to_index_forclick(x, y)[1..2])

      # change cursor shape
      window.cursor = Gdk::Cursor.new(cursor_name_of(x, y))
      true # stop propagation
    end

    def signal_do_leave_notify_event(_)
      notice 'MiraclePainter*leave_notify_event(ev)' if VERBOSE

      iob_main_leave
      # textselector_release
      # restore cursor shape
      window.cursor = Gdk::Cursor.new('default')
      true # stop propagation
    end

    def signal_do_focus_in_event(_)
      notice 'MiraclePainter*focus_in_event(ev)' if VERBOSE

      @selected = true
      true # stop propagation
    end

    def signal_do_focus_out_event(_)
      notice 'MiraclePainter*focus_out_event(ev)' if VERBOSE

      @selected = false
      textselector_unselect
      true # stop propagation
    end
  end

=begin
  def released(x=nil, y=nil)
    if not destroyed?
      if(x == y and not x)
        unselect
      else
        textselector_release(*main_pos_to_index_forclick(x, y)[1..2]) end end end

  # 座標 ( _x_ , _y_ ) にクリックイベントを発生させる
  def clicked(x, y, event)
    signal_emit(:click, event, x, y)
    case event.button
    when 1
      iob_clicked(x, y)
      if not textselector_range
        index = main_pos_to_index(x, y)
        if index
          clicked_note = score.find{|note|
            index -= note.description.size
            index <= 0
          }
          Plugin.call(:open, clicked_note) if clickable?(clicked_note)
        end
      end
    when 3
      @tree.get_ancestor(Gtk::Window).set_focus(@tree)
      Plugin::GUI::Command.menu_pop
    end end

  def on_selected
    if not frozen?
      @selected = true
      on_modify end end

  def on_unselected
    if not frozen?
      @selected = false
      on_modify end end

  # 座標 ( _x_ , _y_ ) にマウスオーバーイベントを発生させる
  def point_moved(ev, x, y)
    point_moved_main_icon(x, y)
    signal_emit(:motion_notify_event, ev)
    textselector_select(*main_pos_to_index_forclick(x, y)[1..2])

    # change cursor shape
    set_cursor(cursor_name_of(x, y))
  end

  # leaveイベントを発生させる
  def point_leaved(ev, x, y)
    iob_main_leave
    signal_emit(:leave_notify_event, ev)
    # textselector_release

    # restore cursor shape
    set_cursor('default')
  end

  # _name_ に対応するマウスカーソルに変更する。
  # ==== Args
  # [name] カーソルの名前(String)
  private def set_cursor(name)
    window = @tree.get_ancestor Gtk::Window
    type =
      case name
      when 'pointer'
        Gdk::Cursor::HAND2
      when 'text'
        Gdk::Cursor::XTERM
      else
        Gdk::Cursor::LEFT_PTR
      end
    window.window.cursor = Gdk::Cursor.new(type)
    self
  end

  # MiraclePainterが選択解除されたことを通知する
  def unselect
    textselector_unselect end
=end

  def iob_icon_pixbuf
    [ ["reply.png".freeze, message.user.verified? ? "verified.png" : "etc.png"],
      [if message.user.protected? then "protected.png".freeze else "retweet.png".freeze end,
       message.favorite? ? "unfav.png".freeze : "fav.png".freeze] ] end

  def iob_icon_pixbuf_off
    world, = Plugin.filtering(:world_current, nil)
    [ [(UserConfig[:show_replied_icon] and message.mentioned_by_me? and "reply.png".freeze),
       UserConfig[:show_verified_icon] && message.user.verified? && "verified.png"],
      [ if UserConfig[:show_protected_icon] and message.user.protected?
          "protected.png".freeze
        elsif Plugin[:miracle_painter].shared?(message, world)
          "retweet.png".freeze end,
       message.favorite? ? "unfav.png".freeze : nil]
    ]
  end

  def iob_reply_clicked
    @tree.imaginary.create_reply_postbox(message) end

  def iob_retweet_clicked
    world, = Plugin.filtering(:world_current, nil)
    if Plugin[:miracle_painter].shared?(message, world)
      retweet = message.retweeted_statuses.find(&:from_me?)
      retweet.destroy if retweet
    else
      Plugin[:miracle_painter].share(message, world)
    end
  end

  def iob_fav_clicked
    message.favorite(!message.favorite?)
  end

  def iob_etc_clicked
  end

  # つぶやきの左上座標から、クリックされた文字のインデックスを返す
  def main_pos_to_index(x, y)
    x -= main_text_rect.x
    y -= main_text_rect.y
    inside, byte, trailing = *main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    main_message.text.get_index_from_byte(byte) if inside end

  def main_pos_to_index_forclick(x, y)
    x -= main_text_rect.x
    y -= main_text_rect.y
    result = main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    result[1] = main_message.text.get_index_from_byte(result[1])
    return *result end

  # def signal_do_modified()
  # end

  # def signal_do_expose_event()
  # end

=begin
  # 更新イベントを発生させる
  def on_modify(event=true)
    if not destroyed?
      @pixbuf = nil
      @coordinate = nil
      signal_emit('modified') if event
    end
  end

  # 画面上にこれが表示されているかを返す
  def visible?
    # TODO: gtk3, visible_rangeをgtk3 gemで定義する
    # if tree
    #   range = tree.visible_range
    #   if range and 2 == range.size
    #     Range.new(*range).cover?(tree.get_path_by_message(@message)) end end end
    true
  end

  def destroy
    def self.tree
      raise DestroyedError.new end
    def self.message
      raise DestroyedError.new end
    def self.p_message
      raise DestroyedError.new end

    instance_variables.each{ |v|
      instance_variable_set(v, nil) }

    @tree = nil
    signal_emit('destroy')
    super
    freeze
  end
=end

private

  def main_icon_rect
    @main_icon_rect ||= Rect.new(MARGIN, MARGIN, *ICON_SIZE)
  end

  # 本文(model#description)
  def main_text_rect
    Rect.new(
      ICON_SIZE[0] + 2 * MARGIN,
      header_text_rect.bottom,
      @width - ICON_SIZE[0] - 4 * MARGIN,
      0
    )
  end

  def header_text_rect
    Rect.new(
      ICON_SIZE[0] + 2 * MARGIN,
      MARGIN,
      @width - ICON_SIZE[0] - 4 * MARGIN,
      header_left.size[1] / Pango::SCALE
    )
  end

  # 本文のための Pango::Layout のインスタンスを返す
  def main_message(context = nil)
    # TODO: gtk3 use Object#tap
    layout = (context || self).create_pango_layout
    font = Plugin.filtering(:message_font, message, nil).last
    layout.font_description = font_description(font) if font
    layout.width = main_text_rect.width * Pango::SCALE
    layout.attributes = textselector_attr_list(description_attr_list(emoji_height: layout.font_description.forecast_font_size))
    layout.wrap = Pango::WrapMode::CHAR
    color = Plugin.filtering(:message_font_color, message, nil).last
    color = BLACK if not(color and color.is_a? Array and 3 == color.size)
    context.set_source_rgb(*color.map{ |c| c.to_f / 65536 }) if context
    layout.text = plain_description

    return layout until layout.context
    layout.context.set_shape_renderer do |c, shape, _|
      return layout until photo = shape.data
      width, height = shape.ink_rect.width/Pango::SCALE, shape.ink_rect.height/Pango::SCALE
      # pixbuf = photo.load_pixbuf(width: width, height: height){ on_modify }
      pixbuf = photo.load_pixbuf(width: width, height: height) do
        queue_draw
      end
      x = layout.index_to_pos(shape.start_index).x / Pango::SCALE
      y = layout.index_to_pos(shape.start_index).y / Pango::SCALE
      c.translate(x, y)
      c.set_source_pixbuf(pixbuf)
      c.rectangle(0, 0, width, height)
      c.fill
    end
    layout
  end

  @@font_description = Hash.new{|h,k| h[k] = {} } # {scale => {font => FontDescription}}
  def font_description(font)
    @@font_description[Gdk.scale(0xffff)][font] ||=
      Pango::FontDescription.new(font).tap{|fd| fd.size = Gdk.scale(fd.size) }
  end

  # 絵文字を描画する時の一辺の大きさを返す
  # ==== Args
  # [font] font description
  # ==== Return
  # [Integer] 高さ(px)
  def emoji_height(font)
    font.forecast_font_size
  end
  deprecate :emoji_height, "Pango::FontDescription#forecast_font_size", 2020, 6


  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = nil)
    attr_list, text = header_left_markup
    color = Plugin.filtering(:message_header_left_font_color, message, nil).last
    color = BLACK if not(color and color.is_a? Array and 3 == color.size)
    font = Plugin.filtering(:message_header_left_font, message, nil).last
    layout = context&.create_pango_layout || create_pango_layout
    layout.attributes = attr_list
    context.set_source_rgb(*color.map{ |c| c.to_f / 65536 }) if context
    layout.font_description = font_description(font) if font
    layout.text = text
    layout end

  def header_left_markup
    user = message.user
    if user.respond_to?(:idname)
      Pango.parse_markup("<b>#{Pango.escape(rinsuki_abbr(user))}</b> #{Pango.escape(user.name || '')}")
    else
      Pango.parse_markup(Pango.escape(user.name || ''))
    end
  end

  def rinsuki_abbr(user)
    return user.idname unless UserConfig[:idname_abbr]
    prefix, domain = user.idname.split('@', 2)
    if domain
      "#{prefix}@#{domain.gsub(NUMERONYM_MATCHER, &NUMERONYM_CONVERTER)}"
    else
      user.idname
    end
  end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context)
    hms = timestamp_label
    attr_list, text = Pango.parse_markup(hms)
    layout = context.create_pango_layout
    layout.attributes = attr_list
    font = Plugin.filtering(:message_header_right_font, message, nil).last
    layout.font_description = font_description(font) if font
    layout.text = text
    layout.alignment = Pango::Alignment::RIGHT
    layout end

  def timestamp_label
    now = Time.now
    if message.created.year == now.year && message.created.month == now.month && message.created.day == now.day
      Pango.escape(message.created.strftime('%H:%M:%S'))
    else
      Pango.escape(message.created.strftime('%Y/%m/%d %H:%M:%S'))
    end
  end

  # アイコンのpixbufを返す
  def main_icon
    w, h = ICON_SIZE
    @main_icon ||= model.user.icon.load_pixbuf(width: w, height: h) do
      queue_draw
    end
  end

  # 背景色を返す
  def get_backgroundcolor
    color = Plugin.filtering(:message_background_color, self, nil).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      WHITE end end

  # Graphic Context にパーツを描画
  def render_to_context(context)
    render_background context
    render_main_icon context
    render_main_text context
    render_parts context end

  def render_background(context)
    context.save do
      context.set_source_rgb(*get_backgroundcolor)
      context.rectangle(0, 0, allocation.width, allocation.height)
      context.fill
      if Gtk.konami
        context.save do
          context.translate(width - 48, height - 54)
          context.set_source_pixbuf(Gtk.konami_image)
          context.paint end end end end

  def render_main_icon(context)
    case Plugin.filtering(:main_icon_form, :square)[0]
    when :aspectframe
      render_main_icon_aspectframe(context)
    else
      render_main_icon_square(context)
    end
  end

  def render_main_icon_square(context)
    context.save{
      context.translate(main_icon_rect.x, main_icon_rect.y)
      context.set_source_pixbuf(main_icon)
      context.paint
    }
    if not (message.system?)
      render_icon_over_button(context) end
  end

  def render_main_icon_aspectframe(context)
    context.save do
      context.save do
        context.translate(main_icon_rect.x, main_icon_rect.y + icon_height*13/14)
        # context.set_source_pixbuf(gb_foot.load_pixbuf(width: icon_width, height: icon_width*9/20){|_pb, _s| on_modify })
        w, = ICON_SIZE
        context.set_source_pixbuf(
          gb_foot.load_pixbuf(width: w, height: 9 / 20 * w) { queue_draw }
        )
        context.paint
      end
      context.translate(main_icon_rect.x, main_icon_rect.y)
      context.append_path(Cairo::SpecialEdge.path(*ICON_SIZE))
      context.set_source_rgb(0,0,0)
      context.stroke
      context.append_path(Cairo::SpecialEdge.path(*ICON_SIZE))
      context.set_source_pixbuf(main_icon)
      context.fill
    end
    if not (message.system?)
      render_icon_over_button(context) end
  end

  def render_main_text(context)
    context.save{
      context.translate(header_text_rect.x, header_text_rect.y)
      context.set_source_rgb(0,0,0)
      hl_layout = header_left(context)
      context.show_pango_layout(hl_layout)
      hr_layout = header_right(context)
      hr_color = Plugin.filtering(:message_header_right_font_color, message, nil).last
      hr_color = BLACK if not(hr_color and hr_color.is_a? Array and 3 == hr_color.size)

      @hl_region = Cairo::Region.new([header_text_rect.x, header_text_rect.y,
                                        hl_layout.size[0] / Pango::SCALE, hl_layout.size[1] / Pango::SCALE])
      @hr_region = Cairo::Region.new([header_text_rect.x + header_text_rect.width - (hr_layout.size[0] / Pango::SCALE), header_text_rect.y,
                                        hr_layout.size[0] / Pango::SCALE, hr_layout.size[1] / Pango::SCALE])

      context.save{
        context.translate(header_text_rect.width - (hr_layout.size[0] / Pango::SCALE), 0)
        if (hl_layout.size[0] / Pango::SCALE) > (header_text_rect.width - (hr_layout.size[0] / Pango::SCALE) - 20)
          r, g, b = get_backgroundcolor
          grad = Cairo::LinearPattern.new(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, 0)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.size[0] / Pango::SCALE + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, hr_layout.size[1] / Pango::SCALE)
          context.set_source(grad)
          context.fill() end
        context.set_source_rgb(*hr_color.map{ |c| c.to_f / 65536 })
        context.show_pango_layout(hr_layout) } }
    context.save{
      context.translate(main_text_rect.x, main_text_rect.y)
      context.show_pango_layout(main_message(context)) } end

  def mainpart_height
    [
      (main_message.size[1] + header_left.size[1]) / Pango::SCALE,
      ICON_SIZE[1],
    ].max + MARGIN
  end

  # このMiraclePainterの(x , y)にマウスポインタがある時に表示すべきカーソルの名前を返す。
  # ==== Args
  # [x] x座標(Integer)
  # [y] y座標(Integer)
  # ==== Return
  # [String] カーソルの名前
  def cursor_name_of(x, y)
    index = main_pos_to_index(x, y)
    if index # the cursor is placed on text
      pointed_note = score.find{|note|
        index -= note.description.size
        index <= 0
      }
      if clickable?(pointed_note)
        # the cursor is placed on link
        'pointer'
      else
        'text'
      end
    else
      'default'
    end
  end

  def gb_foot
    self.class.gb_foot
  end

  class << self
    extend Memoist

    memoize def gb_foot
      Enumerator.new{|y|
        Plugin.filtering(:photo_filter, Cairo::SpecialEdge::FOOTER_URL, y)
      }.first
    end
  end

  class DestroyedError < Exception
  end

end
