# -*- coding: utf-8 -*-

# RubyGnomeを用いてUIを表示するプラグイン
require 'gtk3'

require 'mui/gtk_contextmenu'
require 'mui/gtk_compatlistview'
require 'mui/gtk_crud'
require 'mui/gtk_extension'
require 'mui/gtk_intelligent_textview'
require 'mui/gtk_keyconfig'
require 'mui/gtk_message_picker'
require 'mui/gtk_mtk'
require 'mui/gtk_postbox'
require 'mui/gtk_pseudo_signal_handler'
require 'mui/gtk_selectbox'
require 'mui/gtk_timeline_utils'
require 'mui/gtk_userlist'
require 'mui/gtk_webicon'

require_relative 'widget/timeline'
require_relative 'widget/miraclepainter'
require_relative 'widget/dialog'
require_relative 'widget/tabcontainer'

require_relative 'konami_watcher'
require_relative 'mainloop'
require_relative 'mikutter_window'
require_relative 'tab_toolbar'
require_relative 'slug_dictionary'
require_relative 'settings'

Plugin.create :gtk3 do
  pg = Plugin::Gtk3

  @slug_dictionary = pg::SlugDictionary.new # widget_type => {slug => Gtk}
  @tabs_promise = {}                     # slug => Deferred

  TABPOS = [:top, :bottom, :left, :right].freeze

  # ウィンドウ作成。
  # PostBoxとか複数のペインを持つための処理が入るので、Gtk::MikutterWindowクラスを新設してそれを使う
  on_window_created do |i_window|
    window = pg::MikutterWindow.open i_window, self
    @parent = window
    @slug_dictionary.add(i_window, window)
    window.title = i_window.name

    geometry = get_window_geometry(i_window.slug)
    if geometry
      window.set_default_size(*geometry[:size])
      window.move(*geometry[:position])
    end

    window.ssc(:event){ |window, event|
      if event.is_a? Gdk::EventConfigure
        geometry = (UserConfig[:windows_geometry] || {}).melt
        size = window.window.geometry[2,2]
        position = window.position
        modified = false
        if defined?(geometry[i_window.slug]) and geometry[i_window.slug].is_a? Hash
          geometry[i_window.slug] = geometry[i_window.slug].melt
          if geometry[i_window.slug][:size] != size
            modified = geometry[i_window.slug][:size] = size end
          if geometry[i_window.slug][:position] != position
            modified = geometry[i_window.slug][:position] = position end
        else
          modified = geometry[i_window.slug] = {
            size: size,
            position: position } end
        if modified
          UserConfig[:windows_geometry] = geometry end end
      false }
    window.ssc("destroy"){
      Delayer.freeze
      window.destroy
      Mainloop.reserve_exit
      false
    }
    window.ssc(:focus_in_event) {
      i_window.active!(true, true)
      false
    }
    window.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_window) }
    window.show_all
  end

  on_gui_window_change_icon do |i_window, icon|
    window = widgetof(i_window)
    if window
      window.icon = icon.load_pixbuf(width: 256, height: 256){|pb|
        window.icon = pb if not window.destroyed?
      }
    end
  end

  # ペイン作成。
  # ペインはGtk::NoteBook
  on_pane_created do |i_pane|
    # pane => Gtk::Notebook
    pane = create_pane(i_pane)
    pane.group_name = '0'
    pane.scrollable = true
    pane.show_border = false
    pane.set_tab_pos(TABPOS[UserConfig[:tab_position]])
    pane.hexpand = true
    tab_position_listener = on_userconfig_modify do |key, val|
      next if key != :tab_position
      if pane.destroyed?
        tab_position_listener.detach
      else
        pane.set_tab_pos(TABPOS[val])
      end
    end
    pane.ssc(:page_reordered){ |this, tabcontainer, index|
        Plugin.call(:rewind_window_order, i_pane.parent) if i_pane.parent
      i_tab = tabcontainer.i_tab
      if i_tab
        i_pane.reorder_child(i_tab, index) end
      Plugin.call(:after_gui_tab_reordered, i_tab)
      false }
    pane.ssc :switch_page do |_, tab|
      i_pane.set_active_child(tab.i_tab, true)
    end
    pane.signal_connect(:page_added){ |this, tabcontainer, index|
      type_strict tabcontainer => pg::TabContainer
      Plugin.call(:rewind_window_order, i_pane.parent) if i_pane.parent
      i_tab = tabcontainer.i_tab
      next false if i_tab.parent == i_pane
      Plugin.call(:after_gui_tab_reparent, i_tab, i_tab.parent, i_pane)
      i_pane.add_child(i_tab, index)
      false }
    # 子が無くなった時 : このpaneを削除
    pane.signal_connect(:page_removed){
      if not(pane.destroyed?) and pane.children.empty? and pane.parent
        pane.parent.remove(pane)
        tab_position_listener.detach
        pane_order_delete(i_pane)
        i_pane.destroy end
      false }
  end

  # タブ作成。
  # タブには実体が無いので、タブのアイコンのところをGtk::EventBoxにしておいて、それを実体ということにしておく
  on_tab_created do |i_tab|
    tab = create_tab(i_tab)
    if @tabs_promise[i_tab.slug]
      @tabs_promise[i_tab.slug].call(tab)
      @tabs_promise.delete(i_tab.slug) end end

  on_cluster_created do |i_cluster|
    pane = create_pane(i_cluster)
    pane.ssc(:page_reordered) do |this, tabcontainer, index|
      tabcontainer.i_tab&.yield_self do |i_tab|
        i_cluster.reorder_child(i_tab, index)
        Plugin.call(:after_gui_tab_reordered, i_tab)
      end
      false
    end
  end

  on_fragment_created do |i_fragment|
    create_tab(i_fragment) end

  # タブを作成する
  # ==== Args
  # [i_tab] タブ
  # ==== Return
  # Tab(Gtk::EventBox)
  def create_tab(i_tab)
    tab = Gtk::EventBox.new
    tab.tooltip_text = i_tab.name
    tab.visible_window = false
    @slug_dictionary.add(i_tab, tab)
    tab_update_icon(i_tab)
    tab.ssc(:focus_in_event) {
      i_tab.active!(true, true)
      false
    }
    tab.ssc(:key_press_event){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_tab) }
    tab.ssc(:button_press_event) { |this, event|
      if event.button == 3
        Plugin::GUI::Command.menu_pop(i_tab)
      else
        Plugin::GUI.keypress(::Gtk::buttonname([event.event_type, event.button, event.state]), i_tab)
      end
      false }
    tab.ssc(:destroy) {
      i_tab.destroy
      false }
    tab.show_all end

  on_tab_toolbar_created do |i_tab_toolbar|
    tab_toolbar = pg::TabToolbar.new(i_tab_toolbar).show_all
    @slug_dictionary.add(i_tab_toolbar, tab_toolbar)
  end

  on_gui_tab_toolbar_join_tab do |i_tab_toolbar, i_tab|
    widget = widgetof(i_tab_toolbar)
    widget_join_tab(i_tab, widget) if widget
  end

  # タイムライン作成。
  on_timeline_created do |i_timeline|
    timeline = pg::Timeline.new(i_timeline)
    @slug_dictionary.add(i_timeline, timeline)
    timeline.listbox.ssc(key_press_event: timeline_key_press_event(i_timeline),
                         focus_in_event:  timeline_focus_in_event(i_timeline),
                         destroy:         timeline_destroy_event(i_timeline))
    timeline.show_all
  end

  # Timelineウィジェットのfocus_in_eventのコールバックを返す
  # ==== Args
  # [i_timeline] タイムラインのインターフェイス
  # ==== Return
  # Proc
  def timeline_focus_in_event(i_timeline)
    lambda { |this, event|
      if this.focus?
        i_timeline.active!(true, true) end
      false } end

  # Timelineウィジェットのkey_press_eventのコールバックを返す
  # ==== Args
  # [i_timeline] タイムラインのインターフェイス
  # ==== Return
  # Proc
  def timeline_key_press_event(i_timeline)
    lambda { |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_timeline) } end

  # Timelineウィジェットのdestroyのコールバックを返す
  # ==== Args
  # [i_timeline] タイムラインのインターフェイス
  # ==== Return
  # Proc
  def timeline_destroy_event(i_timeline)
    lambda { |this|
      i_timeline.destroy
      false } end

  on_gui_pane_join_window do |i_pane, i_window|
    window = widgetof(i_window)
    pane = widgetof(i_pane)
    pane.parent && pane.parent != window.panes and pane.parent.remove(pane)
    # 左端にペインを追加
    pane.parent && pane.parent == window.panes or
      window.panes.attach_next_to pane, nil, :left, 1, 1
  end

  on_gui_tab_join_pane do |i_tab, i_pane|
    i_widget = i_tab.children.first
    next if not i_widget
    widget = widgetof(i_widget)
    next if not widget
    tab = widgetof(i_tab)
    pane = widgetof(i_pane)
    old_pane = widget.get_ancestor(::Gtk::Notebook)
    if tab and pane and old_pane and pane != old_pane
      if tab.parent
        page_num = tab.parent.get_tab_pos_by_tab(tab)
        if page_num
          tab.parent.remove_page(page_num)
        else
          raise Plugin::Gtk::GtkError, "#{tab} not found in #{tab.parent}" end end
      i_tab.children.each{ |i_child|
        w_child = widgetof(i_child)
        w_child.parent.remove(w_child)
        widget_join_tab(i_tab, w_child) }
      tab.show_all end
    Plugin.call(:rewind_window_order, i_pane.parent) if i_pane.parent
  end

  on_gui_timeline_join_tab do |i_timeline, i_tab|
    widget = widgetof(i_timeline)
    widget_join_tab(i_tab, widget) if widget end

  on_gui_cluster_join_tab do |i_cluster, i_tab|
    widget = widgetof(i_cluster)
    widget_join_tab(i_tab, widget) if widget end

  on_gui_timeline_add_messages do |i_timeline, messages|
    timeline = widgetof(i_timeline)
    timeline.push_all!(messages) if timeline and not timeline.destroyed? end

  on_gui_postbox_join_widget do |i_postbox|
    type_strict i_postbox => Plugin::GUI::Postbox
    i_postbox_parent = i_postbox.parent
    next if not i_postbox_parent
    postbox_parent = widgetof(i_postbox_parent)
    next if not postbox_parent
    postbox = @slug_dictionary.add(i_postbox, postbox_parent.add_postbox(i_postbox))
    postbox.post.ssc(:focus_in_event) {
      i_postbox.active!(true, true)
      false }

    postbox.post.ssc("populate-popup"){ |widget, menu|
      (event, items) = Plugin::GUI::Command.get_menu_items(i_postbox)

      menu.append(Gtk::SeparatorMenuItem.new) if items.length != 0
      menu2 = Gtk::ContextMenu.new(*items).build!(i_postbox, event, menu)
      menu2.show_all

      true }

    postbox.post.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_postbox) }
    postbox.post.ssc(:destroy){
      i_postbox.destroy
      false }
  end

  on_gui_tab_change_icon do |i_tab|
    tab_update_icon(i_tab) end

  on_tab_toolbar_rewind do |i_tab_toolbar|
    tab_toolbar = widgetof(i_tab_toolbar)
    tab_toolbar&.set_button end

  on_gui_contextmenu do |event, contextmenu|
    widget = widgetof(event.widget)
    if widget
      ::Gtk::ContextMenu.new(*contextmenu).popup(widget, event) end end

  on_gui_timeline_clear do |i_timeline|
    timeline = widgetof(i_timeline)
    if timeline
      timeline.clear end end

  on_gui_timeline_scroll do |i_timeline, msg|
    tl = widgetof(i_timeline) or next

    case msg
    when :top
      iter = tl.model.iter_first or next
      tl.set_cursor iter.path, nil, false

    when :up
      tl.move_cursor ::Gtk::MovementStep::PAGES, -1

    when :down
      tl.move_cursor ::Gtk::MovementStep::PAGES, 1
    end
  end

  on_gui_timeline_move_cursor_to do |i_timeline, message|
    tl = widgetof(i_timeline)
    if tl
      path, column = tl.cursor
      if path and column
        case message
        when :prev
          path.prev!
          tl.set_cursor(path, column, false)
        when :next
          path.next!
          tl.set_cursor(path, column, false)
        else
          if message.is_a? Integer
            path, = *tl.get_path(0, message)
              tl.set_cursor(path, column, false) if path end end end end end

  on_gui_timeline_set_order do |i_timeline, order|
    widgetof(i_timeline).order = order
  end

  filter_gui_timeline_select_messages do |i_timeline, messages|
    timeline = widgetof(i_timeline)
    if timeline
      [i_timeline,
       messages.select(&timeline.method(:include?))]
    else
      [i_timeline, messages]
    end
  end

  filter_gui_timeline_reject_messages do |i_timeline, messages|
    w_timeline = widgetof(i_timeline)
    if w_timeline
      [i_timeline,
       messages.reject(&w_timeline.method(:include?))]
    else
      [i_timeline, messages]
    end
  end

  on_gui_postbox_post do |i_postbox, options|
    widgetof(i_postbox)&.post_it(world: options[:world])
  end

  # i_widget.destroyされた時に呼ばれる。
  # 必要ならば、ウィジェットの実体もあわせて削除する。
  on_gui_destroy do |i_widget|
    widget = widgetof(i_widget)
    if widget and not widget.destroyed?
      if i_widget.is_a?(Plugin::GUI::Tab) and i_widget.parent
        pane = widgetof(i_widget.parent)
        if pane
          pane.n_pages.times{ |pagenum|
            if widget == pane.get_tab_label(pane.get_nth_page(pagenum))
              Plugin.call(:rewind_window_order, i_widget.parent.parent)
              pane.remove_page(pagenum)
              break end } end
      else
        widget.parent.remove(widget) if widget.parent
        widget.destroy end end end

  # 互換性のため
  on_mui_tab_regist do |container, name, icon|
    slug = name.to_sym
    i_tab = Plugin::GUI::Tab.instance(slug, name)
    i_tab.set_icon(icon).expand
    i_container = Plugin::GUI::TabChildWidget.instance
    @slug_dictionary.add(i_container, container)
    i_tab << i_container
    @tabs_promise[i_tab.slug] = (@tabs_promise[i_tab.slug] || Deferred.new).next{ |tab|
      widget_join_tab(i_tab, container.show_all) } end

  # Gtkオブジェクトをタブに入れる
  on_gui_nativewidget_join_tab do |i_tab, i_container, container|
    @slug_dictionary.add(i_container, container)
    widget_join_tab(i_tab, container.show_all) end

  on_gui_nativewidget_join_fragment do |i_fragment, i_container, container|
    @slug_dictionary.add(i_container, container)
    widget_join_tab(i_fragment, container.show_all) end

  on_gui_window_rewindstatus do |i_window, text, expire|
    window = @slug_dictionary.get(Plugin::GUI::Window, :default)
    next if not window
    statusbar = window.statusbar
    cid = statusbar.get_context_id("system")
    mid = statusbar.push(cid, text)
    if expire != 0
      Delayer.new(delay: expire) do
        if not statusbar.destroyed?
          statusbar.remove(cid, mid)
        end
      end
    end
  end

  on_gui_child_activated do |i_parent, i_child, activated_by_toolkit|
    type_strict i_parent => Plugin::GUI::HierarchyParent, i_child => Plugin::GUI::HierarchyChild
    activated_by_toolkit or next

    if i_child.is_a?(Plugin::GUI::TabLike)
      i_pane = i_parent
      i_tab = i_child
      pane = widgetof(i_pane)
      tab = widgetof(i_tab)
      pane && tab and pane.page = pane.get_tab_pos_by_tab(tab)
    elsif i_parent.is_a?(Plugin::GUI::Window)
      i_term = if i_child.respond_to?(:active_chain)
                 i_child.active_chain.last 
               else
                 i_child
               end
      i_term or next

      window = widgetof(i_parent)
      widget = widgetof(i_term)
      widget&.can_focus? and window&.focus = widget
    end
  end

  on_posted do |service, messages|
    messages.each{ |message|
      if(replyto_source = message.replyto_source)
        # Gdk::MiraclePainter.findbymessage(replyto_source).each{ |mp| mp.on_modify }
      end
    }
  end

  on_favorite do |service, user, message|
    if(user.me?)
      # Gdk::MiraclePainter.findbymessage(message).each{ |mp| mp.on_modify }
    end
  end

  on_konami_activate do
    Gtk.konami_load
  end

  filter_gui_postbox_input_editable do |i_postbox, editable|
    postbox = widgetof(i_postbox)
    if postbox
      [i_postbox, postbox && postbox.post.editable?]
    else
      [i_postbox, editable] end end

  filter_gui_timeline_cursor_position do |i_timeline, y|
    timeline = widgetof(i_timeline)
    if timeline
      path, column = *timeline.cursor
      if path
        rect = timeline.get_cell_area(path, column)
        next [i_timeline, rect.y + (rect.height / 2).to_i] end
    end
    [i_timeline, y] end

  filter_gui_timeline_selected_messages do |i_timeline, messages|
    timeline = widgetof(i_timeline)
    if timeline
      [i_timeline, messages + timeline.active_models]
    else
      [i_timeline, messages] end end

  filter_gui_timeline_selected_text do |i_timeline, message, text|
    next [i_timeline, message, text]

    # timeline = widgetof(i_timeline)
    # next [i_timeline, message, text] if not timeline
    # record = timeline.get_record_by_message(message)
    # next [i_timeline, message, text] if not record
    # range = record.miracle_painter.textselector_range
    # next [i_timeline, message, text] if not range
    # if UserConfig[:miraclepainter_expand_custom_emoji]
    #   adjust = score_of(message).each_with_object(Hash.new(0)) do |note, state|
    #     if note.respond_to?(:inline_photo)
    #       # 1 -> cairo_markup_generatorで便宜上置換された、絵文字の文字長
    #       if range.include?(state[:index])
    #         state[:end] += note.description.size - 1
    #       elsif state[:index] < range.begin
    #         state[:begin] += note.description.size - 1
    #       end
    #       state[:index] += 1
    #     else
    #       state[:index] += note.description.size
    #     end
    #   end
    #   range = Range.new(range.begin + adjust[:begin], range.end + adjust[:begin] + adjust[:end], true)
    # end
    # [i_timeline, message, score_of(message).map(&:description).join[range]]
  end

  filter_gui_destroyed do |i_widget|
    if i_widget.is_a? Plugin::GUI::Widget
      [!widgetof(i_widget)]
    else
      [i_widget] end end

  filter_gui_get_gtk_widget do |i_widget|
    [widgetof(i_widget)] end

  on_gui_dialog do |plugin, title, default, proc, promise|
    pg::Dialog.open(plugin: plugin,
                             title: title,
                             default: default,
                             promise: promise,
                             parent: @parent,
                             &proc)
  end

  filter_before_mainloop_exit do
    if !@slug_dictionary.widgets(Plugin::GUI::Window).all?(&:destroyed?)
      error "Filter before_mainloop_exit was canceled because window already exists."
      Plugin.filter_cancel!
    end
    []
  end

  # タブ _tab_ に _widget_ を入れる
  # ==== Args
  # [i_tab] タブ
  # [widget] Gtkウィジェット
  def widget_join_tab(i_tab, widget)
    tab = widgetof(i_tab)
    return false if not tab
    i_pane = i_tab.parent
    return false if not i_pane
    pane = widgetof(i_pane)
    return false if not pane
    is_tab = i_tab.is_a?(Plugin::GUI::Tab)
    has_child = is_tab and
      not(i_tab.temporary_tab?) and
      not(i_tab.children.any?{ |child|
            not child.is_a? Plugin::GUI::TabToolbar })
    if has_child
      Plugin.call(:rewind_window_order, i_pane.parent) end
    container_index = pane.get_tab_pos_by_tab(tab)
    if container_index
      container = pane.get_nth_page(container_index)
      if container
        widget.vexpand = i_tab.pack_rule[container.children.size]
        return container.add(widget) end end
    if tab.parent
      raise Plugin::Gtk3::GtkError, "Gtk Widget #{tab.inspect} of Tab(#{i_tab.slug.inspect}) has parent Gtk Widget #{tab.parent.inspect}" end
    container = Plugin::Gtk3::TabContainer.new(i_tab).show_all
    container.ssc(:key_press_event){ |w, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_tab) }
    widget.vexpand = i_tab.pack_rule[container.children.size]
    container.add(widget)
    pos = where_should_insert_it(
      i_tab,
      pane.each_pages.map{ |target_page|
        find_implement_widget_by_gtkwidget(pane.get_tab_label(target_page))
      },
      i_tab.parent.children
    )
    pane.insert_page(container, tab, pos)
    pane.set_tab_reorderable(container, true).set_tab_detachable(container, true)
    true end

  def tab_update_icon(i_tab)
    type_strict i_tab => Plugin::GUI::TabLike
    tab = widgetof(i_tab)
    if tab
      tab.tooltip_text = i_tab.name
      tab.remove(tab.child) if tab.child
      if i_tab.icon
        tab.add(::Gtk::WebIcon.new(i_tab.icon, 24, 24).show)
      else
        tab.add(::Gtk::Label.new(i_tab.name).show) end end
    self end

  def get_window_geometry(slug)
    type_strict slug => Symbol
    geometry = UserConfig[:windows_geometry]
    geometry and geometry[slug]
  end

  # ペインを作成
  # ==== Args
  # [i_pane] ペイン
  # ==== Return
  # ペイン(Gtk::Notebook)
  def create_pane(i_pane)
    pane = Gtk::Notebook.new
    @slug_dictionary.add(i_pane, pane)
    pane.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_pane) }
    pane.ssc(:destroy){
      i_pane.destroy if i_pane.destroyed?
      false }
    pane.show_all end

  # ウィンドウ内のペイン、タブの現在の順序を設定に保存する
  on_rewind_window_order do |i_window|
    if :default == i_window.slug
      panes_order = Hash[
        i_window.children.select { |i_pane|
          i_pane.is_a?(Plugin::GUI::Pane)
        }.map { |i_pane|
          pane = widgetof(i_pane)
          tab_order = pane.each_pages.map { |page|
            find_implement_widget_by_gtkwidget(pane.get_tab_label(page))
          }.select { |i_widget|
            i_widget &&
              !i_widget.temporary_tab? &&
              i_widget.children.any? { |child| !child.is_a?(Plugin::GUI::TabToolbar) }
          }.map(&:slug)
          [i_pane.slug, tab_order] if !tab_order.empty?
        }.compact
      ]
      ui_tab_order = (UserConfig[:ui_tab_order] || {}).melt
      ui_tab_order[i_window.slug] = panes_order
      UserConfig[:ui_tab_order] = ui_tab_order
    end
  end

  # ペインを順序リストから削除する
  # ==== Args
  # [i_pane] ペイン
  def pane_order_delete(i_pane)
    order = UserConfig[:ui_tab_order].melt
    i_window = i_pane.parent
    order[i_window.slug] = order[i_window.slug].melt
    order[i_window.slug].delete(i_pane.slug)
    UserConfig[:ui_tab_order] = order
  end

  # _cuscadable_ に対応するGtkオブジェクトを返す
  # ==== Args
  # [cuscadable] ウィンドウ、ペイン、タブ、タイムライン等
  # ==== Return
  # 対応するGtkオブジェクト
  def widgetof(cuscadable)
    type_strict cuscadable => :slug
    result = @slug_dictionary.get(cuscadable)
    if result and result.destroyed?
      nil
    else
      result end end

  # Gtkオブジェクト _widget_ に対応するウィジェットのオブジェクトを返す
  # ==== Args
  # [widget] Gtkウィジェット
  # ==== Return
  # _widget_ に対応するウィジェットオブジェクトまたは偽
  def find_implement_widget_by_gtkwidget(widget)
    @slug_dictionary.imaginally_by_gtk(widget) end

  # timeline_maxを取得するフィルタ
  filter_gui_timeline_get_timeline_max do |i_tl, _|
    [i_tl, widgetof(i_tl).timeline_max]
  end

  # timeline_maxを設定するフィルタ
  filter_gui_timeline_set_timeline_max do |i_tl, n|
    widgetof(i_tl).timeline_max = n
    [i_tl, n]
  end

  # タイムラインのメッセージを順に処理するフィルタ
  filter_gui_timeline_each_messages do |i_tl, y|
    widgetof(i_tl).each do |m|
      y << m
    end
    [i_tl, y]
  end

end

module Plugin::Gtk3
  class GtkError < Exception
  end end
