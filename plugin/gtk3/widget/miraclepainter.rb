# frozen_string_literal: true

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

module Plugin::Gtk3
  # Diva::Modelを表示するためのGtk::ListBoxRow。
  # 名前は言いたかっただけ。クラス名まで全てはつね色に染めて♪
  class MiraclePainter < Gtk::ListBoxRow
    # * カスタムwidgetの実装
    #   https://developer.gnome.org/gtkmm-tutorial/stable/sec-custom-widgets.html.en
    # * height-for-widthの実装
    #   https://developer.gnome.org/gtk3/stable/GtkWidget.html#GtkWidget.description
    MARGIN = 3
    SPACING = 3
    EMOJI_SIZE = 18

    type_register

    attr_reader :model
    alias message model

    def initialize(model, as_subparts: false)
      super()

      @model = model
      @as_subparts = as_subparts

      build
    end

    # override virtual function Gtk::Widget.get_request_mode
    def do_get_request_mode
      Gtk::SizeRequestMode::HEIGHT_FOR_WIDTH
    end

    # override virtual function Gtk::Widget.get_preferred_width
    def do_get_preferred_width
      [100, 250] # minimum and natural width
    end

    def signal_do_focus_in
      parent.focus
    end

    def score
      @score ||= Plugin[:gtk3].score_of(model)
    end

  private

    def build
      avatar_image = Gtk::Image.new
      avatar_size = @as_subparts ? UserConfig[:gtk3_subparts_avatar_size]
                                 : UserConfig[:gtk3_avatar_size]
      avatar_image.pixbuf = model.user.icon.load_pixbuf(
        width: avatar_size, height: avatar_size
      ) do |pb|
        avatar_image.pixbuf = pb
      end

      avatar_box = Gtk::EventBox.new
      avatar_box.valign = :start
      avatar_box << avatar_image

      @text_view = Gtk::TextView.new
      @text_view.halign = :fill
      @text_view.expand = true
      build_text_view

      header_label = Gtk::Label.new
      header_label.ellipsize = :end
      header_label.single_line_mode = true
      header_label.xalign = 0
      header_label.markup = header_markup

      timestamp_label = Gtk::Label.new timestamp_text
      timestamp_label.single_line_mode = true
      timestamp_label.xalign = 1

      header_box = Gtk::Box.new :horizontal
      header_box.spacing = SPACING
      header_box.halign = :fill
      header_box.hexpand = true
      header_box.pack_start(header_label, fill: true, expand: true)
                .pack_end(timestamp_label)

      unless @as_subparts
        @subparts_grid = Gtk::Grid.new
        @subparts_grid.orientation = :vertical
        @subparts_grid.halign = :fill
        @subparts_grid.expand = true
        build_subparts
      end

      grid = Gtk::Grid.new
      grid.margin = MARGIN unless @as_subparts
      grid.row_spacing = SPACING
      grid.column_spacing = SPACING

      grid.attach_next_to avatar_box, nil, :bottom, 1, 2
      grid.attach_next_to header_box, avatar_box, :right, 1, 1
      grid.attach_next_to @text_view, header_box, :bottom, 1, 1
      unless @as_subparts
        grid.attach_next_to @subparts_grid, avatar_box, :bottom, 2, 1
      end

      box = Gtk::EventBox.new
      em = Gdk::EventMask
      box.events |= em::BUTTON_PRESS_MASK
      box.ssc :button_press_event do |_, ev|
        activate
        next unless ev.button == Gdk::BUTTON_SECONDARY

        i_timeline = get_ancestor(Timeline).imaginary
        event, items = Plugin::GUI::Command.get_menu_items i_timeline
        menu = Gtk::Menu.new
        menu.attach_to_widget self
        Gtk::ContextMenu.new(*items).build!(i_timeline, event, menu).show_all
        menu.popup_at_pointer ev
        true
      end
      box << grid

      self << box
    end

    def build_text_view
      @text_view.editable = false
      @text_view.wrap_mode = :char

      # provider = Gtk::CssProvider.new
      # provider.load_from_data 'textview, text { background: transparent; }'
      # @text_view.style_context.add_provider provider

      buffer = @text_view.buffer

      @link_notes = {}
      score.reduce(buffer.start_iter) do |iter, note|
        if note.respond_to? :inline_photo
          offset = iter.offset
          pixbuf = note.inline_photo.load_pixbuf(width: EMOJI_SIZE,
                                                 height: EMOJI_SIZE) do |pb|
            new_iter = buffer.get_iter_at offset: offset
            end_iter = buffer.get_iter_at offset: offset + 1
            buffer.delete new_iter, end_iter
            buffer.insert new_iter, pb
          end
          buffer.insert iter, pixbuf

        elsif openable?(note)
          link_label = Gtk::LinkButton.new('').children.find { |w| w.is_a? Gtk::Label }
          rgba = link_label.style_context.get_color Gtk::StateFlags::NORMAL
          tag = buffer.create_tag nil, [[:foreground, rgba.to_s], [:underline, :single]]
          buffer.insert iter, note.description, tags: [tag]
          @link_notes[tag.object_id] = note

        else
          buffer.insert iter, note.description
        end

        iter
      end

      @text_view.ssc :button_press_event do
        activate
        false
      end

      @text_view.ssc :populate_popup do |_, menu|
        i_timeline = get_ancestor(Timeline).imaginary
        event, items = Plugin::GUI::Command.get_menu_items i_timeline
        menu.append Gtk::SeparatorMenuItem.new unless items.empty?
        Gtk::ContextMenu.new(*items).build!(i_timeline, event, menu).show_all
      end

      @text_view.ssc :event_after do |_, ev|
        # make links clickable
        if (ev.type == :button_release && ev.button == Gdk::BUTTON_PRIMARY) ||
            ev.type == :touch_end
          x, y = @text_view.window_to_buffer_coords :widget, ev.x, ev.y
          iter = @text_view.get_iter_at_location(x, y) or next false
          iter.tags.empty? and next false
          note = @link_notes[iter.tags.first.object_id] or next false
          Plugin.call :open, note
        end
      end

      # change cursor shape on links
      default_cursor = Gdk::Cursor.new 'default'
      text_cursor = Gdk::Cursor.new 'text'
      pointer_cursor = Gdk::Cursor.new 'pointer'
      hovering_over_link = false
      @text_view.ssc :motion_notify_event do |_, ev|
        x, y = @text_view.window_to_buffer_coords :widget, ev.x, ev.y
        iter = @text_view.get_iter_at_location x, y
        unless iter
          hovering_over_link = false
          window = @text_view.get_window :text
          window.cursor = default_cursor
          next false
        end
        hovering = !iter.tags.empty?
        window = @text_view.get_window :text
        window.cursor = hovering ? pointer_cursor : text_cursor
        hovering_over_link = hovering
        false
      end
    end

    def build_iob

    end

    def build_subparts
      Plugin.collect(:subparts_widgets, model).each do |w|
        w.halign = :fill
        w.hexpand = true
        @subparts_grid << w
      end
    end

    def timestamp_text
      now = Time.now
      if model.created.year == now.year &&
          model.created.month == now.month &&
          model.created.day == now.day
        Pango.escape(model.created.strftime('%H:%M:%S'))
      else
        Pango.escape(model.created.strftime('%Y/%m/%d %H:%M:%S'))
      end
    end

    def header_markup
      user = model.user
      name = Pango.escape(user.name || '')
      if user.respond_to?(:idname)
        idname = Pango.escape(rinsuki_abbr(user))
        "<b>#{idname}</b> #{name}"
      else
        name
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

    def openable?(model)
      intent = Plugin.collect(:intent_select_by_model_slug, model.class.slug).first
      return true if intent
      Plugin.collect(:model_of_uri, model.uri).any? do |model_slug|
        Plugin.collect(:intent_select_by_model_slug, model_slug).first
      end
    end
  end
end
