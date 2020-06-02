# -*- coding: utf-8 -*-

=begin rdoc
UIを定義するためのDSLメソッドをクラスに追加するmix-in。
現在の値（初期値）を返す[]メソッドと、値が変更された時に呼ばれる[]=メソッドを定義すること。
includeするクラスはGtk::Gridでなければならない．
=end
module Gtk::FormDSL
  class Chainable
    def initialize(widget)
      @widget = widget
    end

    def tooltip(text)
      @widget.tooltip_text = text
      self
    end

    def native
      @widget
    end
  end

  extend Memoist

  PIXBUF_PHOTO_FILTER = Hash[GdkPixbuf::Pixbuf.formats.map{|f| ["#{f.description} (#{f.name})", f.extensions.flat_map{|x| [x.downcase.freeze, x.upcase.freeze] }.freeze] }].freeze
  PHOTO_FILTER = {'All images' => PIXBUF_PHOTO_FILTER.values.flatten}.merge(PIXBUF_PHOTO_FILTER).merge('All files' => ['*'])

  def initialize(*_, &block)
    super

    type_strict self => Gtk::Grid

    block and instance_eval(&block)
  end

  # 複数行テキスト
  # ==== Args
  # [text] ラベルテキスト
  # [key] キー
  def multitext(text, key)
    label = Gtk::Label.new text
    label.halign = :start

    text_view = Gtk::TextView.new
    text_view.halign = :fill
    text_view.hexpand = true
    text_view.wrap_mode = :char
    text_view.border_width = 6
    text_view.accepts_tab = false
    text_view.editable = true
    self[key] and text_view.buffer.text
    text_view.buffer.ssc :changed do
      self[key] = text_view.buffer.text
      false
    end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to text_view, label, :right, 2, 1

    Chainable.new text_view
  end

  # 特定範囲の数値入力
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  # [lower] 最低値。これより小さい数字は入力できないようになる
  # [upper] 最高値。これより大きい数字は入力できないようになる
  def adjustment(text, key, lower, upper)
    label = Gtk::Label.new text
    label.halign = :start
    label.hexpand = true

    value = (self[key] || lower).to_f
    lower, upper = lower.to_f, upper.to_f
    step = 1.0
    page, page_size = 5.0, 0.0
    adj = Gtk::Adjustment.new value, lower, upper, step, page, page_size
    adj.ssc :value_changed do
      self[key] = adj.value.to_i
      false
    end
    spinner = Gtk::SpinButton.new adj, 0, 0
    spinner.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to spinner, label, :right, 1, 1

    Chainable.new spinner
  end

  # 真偽値入力
  # ==== Args
  # [text] チェックボックスのラベルテキスト
  # [key] キー
  def boolean(text, key, switch: false)
    if switch
      label = Gtk::Label.new text
      label.halign = :start

      switch = Gtk::Switch.new
      switch.active = self[key]
      switch.halign = :end
      switch.ssc :activate do
        self[key] = switch.active?
      end

      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to switch, label, :right, 1, 1

      Chainable.new switch
    else
      check = Gtk::CheckButton.new text
      check.active = self[key]
      check.ssc :toggled do
        self[key] = check.active?
        false
      end

      attach_next_to check, nil, :bottom, 2, 1

      Chainable.new check
    end
  end

  # ファイルを選択する
  # ==== Args
  # [text] ラベルテキスト
  # [key] キー
  # [dir:] 初期のディレクトリ
  # [shortcuts:] ファイル選択ダイアログのサイドバーに表示しておくディレクトリの絶対パスの配列(Array)
  # [filters:] ファイル選択ダイアログの拡張子フィルタ(Hash)。キーはコンボボックスに表示するラベル(String)、値は拡張子の配列(Array)。拡張子はStringで指定する。
  def fileselect(text, key, dir: nil, shortcuts: nil, filters: nil)
    label = Gtk::Label.new text
    label.hexpand = true
    label.halign = :start

    file_chooser = Gtk::FileChooserButton.new text, :open
    (self[key] && ! self[key].empty?) and file_chooser.filename = self[key]
    file_chooser.ssc :file_set do
      self[key] = file_chooser.filename
    end

    dir and file_chooser.current_folder = dir

    shortcuts&.each(&file_chooser.method(:add_shortcut_folder)) 

    filters&.each do |k, v|
      filter = Gtk::FileFilter.new
      filter.name = k
      v.each { |ext| filter.add_pattern "*.#{ext}" }
      file_chooser.add_filter filter
    end

    button = Gtk::Button.new icon_name: 'edit-clear-symbolic'
    button.ssc :clicked do
      file_chooser.unselect_all
      self[key] = nil 
    end

    box = Gtk::Box.new :horizontal
    box.halign = :end
    box.style_context.add_class 'linked'
    box << file_chooser << button 

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to box, label, :right, 1, 1

    Chainable.new file_chooser
  end

  # ファイルを選択する
  # ==== Args
  # [text] ラベルテキスト
  # [key] キー
  # [shortcuts:] ファイル選択ダイアログのサイドバーに表示しておくディレクトリの絶対パスの配列(Array)
  # [filters:] ファイル選択ダイアログの拡張子フィルタ(Hash)。キーはコンボボックスに表示するラベル(String)、値は拡張子の配列(Array)。拡張子はStringで指定する。
  def photoselect(text, key, dir: nil, shortcuts: nil, filters: PHOTO_FILTER)
    label = Gtk::Label.new text
    label.hexpand = true
    label.halign = :start

    size = [18, 18]

    preview_button = Gtk::Button.new
    preview_button.always_show_image = true
    photo = fs_photo_thumbnail self[key]
    preview_button.image = Gtk::WebIcon.new photo, *size
    preview_button.ssc :clicked do
      Plugin.call(:open, fs_photo_thumbnail(self[key]) || self[key])
      true # stop propagation
    end

    entry = Gtk::Entry.new
    entry.secondary_icon_name = 'document-open-symbolic'
    self[key] and entry.text = self[key]
    entry.ssc :changed do
      filename = self[key] = entry.text
      rect = Gdk::Rectangle.new 0, 0, *size
      preview_button.image.load_model fs_photo_thumbnail(filename), rect
    end
    entry.ssc :icon_press do
      file_chooser = Gtk::FileChooserDialog.new(
        title: text, parent: get_ancestor(Gtk::Window), action: :open,
        buttons: [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
                  [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT]]
      )
      dir and file_chooser.current_folder = dir

      file_chooser.preview_widget = Gtk::Image.new
      file_chooser.ssc :update_preview do
        filename = file_chooser.preview_filename
        pixbuf = GdkPixbuf::Pixbuf.new file: filename, width: 128, height: 128
        pixbuf and file_chooser.preview_widget.pixbuf = pixbuf
        file_chooser.preview_widget_active = !!pixbuf
      rescue
        file_chooser.preview_widget_active = false
      end
      file_chooser.ssc :response do |_, response_id|
        case response_id
        when Gtk::ResponseType::ACCEPT
          self[key] = entry.text = file_chooser.filename
          photo = fs_photo_thumbnail self[key]
          preview_button.image = Gtk::WebIcon.new photo, *size
        end
        file_chooser.destroy
      end

      dir and file_chooser.current_folder = dir

      shortcuts&.each(&file_chooser.method(:add_shortcut_folder)) 

      filters&.each do |k, v|
        filter = Gtk::FileFilter.new
        filter.name = k
        v.each { |ext| filter.add_pattern "*.#{ext}" }
        file_chooser.add_filter filter
      end

      file_chooser.show_all
    end

    box = Gtk::Box.new :horizontal
    box.halign = :fill
    box.hexpand = true
    box.style_context.add_class 'linked'
    box << preview_button
    box.pack_start entry, fill: true, expand: true

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to box, label, :right, 1, 1

    Chainable.new entry
  end

  # ディレクトリを選択する
  # ==== Args
  # [text] ラベル
  # [key] 設定のキー
  # [dir:] 初期のディレクトリ
  # [shortcuts:] ファイル選択ダイアログのサイドバーに表示しておくディレクトリの絶対パスの配列(Array)
  def dirselect(text, key, dir: nil, shortcuts: nil)
    # fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_SELECT_FOLDER, title: title, shortcuts: shortcuts)

    label = Gtk::Label.new text
    label.hexpand = true
    label.halign = :start

    file_chooser = Gtk::FileChooserButton.new text, :select_folder
    file_chooser.halign = :end
    (self[key] && ! self[key].empty?) and file_chooser.filename = self[key]
    file_chooser.ssc :file_set do
      self[key] = file_chooser.filename
    end

    dir and file_chooser.current_folder = dir

    shortcuts&.each(&file_chooser.method(:add_shortcut_folder)) 

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to file_chooser, label, :right, 1, 1

    Chainable.new file_chooser
  end

  # 一行テキストボックス
  # ==== Args
  # [text] ラベルテキスト
  # [key] キー
  def input(text, key, action=nil)
    widget_right = entry = build_entry(key)

    if action
      # TODO; gtk3 case action
      button = Gtk::Button.new
      button.image = Gtk::Image.new icon_name: 'edit-paste-symbolic'
      button.ssc :clicked do
        get_clipboard(Gdk::Selection::CLIPBOARD)
          .request_text { |_, text| entry.text = text }
      end

      box = Gtk::Box.new(:horizontal).apply do
        style_context.add_class :linked
        add entry, expand: true
        add button
      end
      widget_right = box
    end

    widget_right.halign = :fill
    widget_right.hexpand = true

    if text
      label = Gtk::Label.new text
      label.halign = :start

      # attach to a new row of the grid
      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to widget_right, label, :right, 1, 1
    else
      # attach to a new row of the grid
      attach_next_to widget_right, nil, :bottom, 2, 1
    end

    Chainable.new widget_right
  end

  # 一行テキストボックス(非表示)
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def inputpass(text, key)
    entry = build_entry(key)
    entry.visibility = false
    entry.halign = :fill
    entry.hexpand = true

    if text
      label = Gtk::Label.new text
      label.halign = :start

      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to entry, label, :right, 1, 1
    else
      attach_next_to entry, nil, :bottom, 2, 1
    end

    Chainable.new entry
  end

  # 複数テキストボックス
  # 任意個の項目を入力させて、配列で受け取る。
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def multi(text, key)
    settings(text) do
      grid = Gtk::Grid.new
      grid.orientation = :vertical
      grid.row_spacing = 6
      grid.halign = :fill
      grid.hexpand = true

      update_config = lambda do
        self[key] = grid.children.map do |box|
          box.children.find { |w| w.is_a? Gtk::Entry }.text
        end.select { |s| ! s.empty? }
      end

      build_box = lambda do |s|
        box = Gtk::Box.new :horizontal
        box.halign = :fill
        box.hexpand = true
        box.style_context.add_class 'linked'

        entry = Gtk::Entry.new
        entry.text = s
        entry.sensitive = false

        button = Gtk::Button.new icon_name: 'list-remove-symbolic'
        button.ssc :clicked do
          grid.remove box
          update_config.()
        end

        box.pack_start(entry, fill: true, expand: true).pack_start(button)
      end

      entry = Gtk::Entry.new
      button = Gtk::Button.new icon_name: 'list-add-symbolic'
      button.sensitive = false

      entry.ssc :changed do
        button.sensitive = ! entry.text.empty?
        false
      end
      entry.ssc :activate do
        button.clicked
        true
      end

      button.ssc :clicked do
        entry.text.empty? and next false

        (grid << build_box.(entry.text)).show_all

        entry.text = ''
        button.sensitive = false

        update_config.()

        true
      end

      box = Gtk::Box.new :horizontal
      box.halign = :fill
      box.hexpand = true
      box.style_context.add_class 'linked'
      box.pack_start(entry, fill: true, expand: true).pack_start(button)

      grid << box
      (self[key] || []).each do |s|
        grid << build_box.(s)
      end

      attach_next_to grid, nil, :bottom, 2, 1
    end
  end

  # 設定のグループ。関連の強い設定をカテゴライズできる。
  # ==== Args
  # [title] ラベル
  # [&block] ブロック
  def settings(title, &block)
    @headings ||= []
    @headings << title

    label = Gtk::Label.new @headings.map { |s| "<b>#{s}</b>" }.join ' > '
    label.use_markup = true
    label.halign = :start
    attach_next_to label, nil, :bottom, 2, 1

    instance_eval(&block)
    @headings.pop

    Chainable.new label
  end

  # 〜についてダイアログを出すためのボタン。押すとダイアログが出てくる
  # ==== Args
  # [text] ラベルテキスト
  # [options]
  #   設定値。以下のキーを含むハッシュ。
  #   _:name_ :: ソフトウェア名
  #   _:version_ :: バージョン
  #   _:copyright_ :: コピーライト
  #   _:comments_ :: コメント
  #   _:license_ :: ライセンス
  #   _:website_ :: Webページ
  #   _:logo_ :: ロゴ画像。 フルパス(String)か、Photo Modelか、GdkPixbuf::Pixbufを指定する
  #   _:authors_ :: 作者の名前。通常MastodonのAcct（Array）
  #   _:artists_ :: デザイナとかの名前。通常MastodonのAcct（Array）
  #   _:documenters_ :: ドキュメントかいた人とかの名前。通常MastodonのAcct（Array）
  def about(text, options={})
    name_mapper = Hash.new{|h,k| k }
    name_mapper[:name] = :program_name

    button = Gtk::Button.new label: text
    button.hexpand = true
    button.signal_connect(:clicked){
      dialog = Gtk::AboutDialog.new.show
      options.each { |key, value|
        dialog.__send__("#{name_mapper[key]}=", about_converter[key][value])
      }
      dialog.signal_connect(:response){
        dialog.destroy
        false
      }
    }

    attach_next_to button, nil, :bottom, 2, 1

    Chainable.new button
  end

  # フォントを決定させる。押すとフォント、サイズを設定するダイアログが出てくる。
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def font(text, key)
    label = Gtk::Label.new text
    label.halign = :start
    font = build_font(key)
    font.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to font, label, :right, 1, 1

    Chainable.new font
  end

  # 色を決定させる。押すと色を設定するダイアログが出てくる。
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def color(text, key)
    label = Gtk::Label.new text
    label.halign = :start
    color = build_color(key)
    color.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to color, label, :right, 1, 1

    Chainable.new color
  end

  # フォントと色を決定させる。
  # ==== Args
  # [text] ラベルテキスト
  # [font_key] フォントの設定のキー
  # [color_key] 色の設定のキー
  def fontcolor(text, font_key, color_key)
    label = Gtk::Label.new text
    label.halign = :start
    right_container = Gtk::Grid.new.tap do |grid|
      grid.column_spacing = 6
      grid << (build_font font_key)
      grid << (build_color color_key)
    end
    right_container.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to right_container, label, :right, 1, 1

    Chainable.new right_container
  end

  # リストビューを表示する。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [columns:]
  #   配列の配列で、各要素は[カラムのタイトル(String), カラムの表示文字を返すProc]
  # [reorder:]
  #   _true_ なら、ドラッグ＆ドロップによる並び替えを許可する
  # [&block] 内容
  def listview(config, columns:, edit: true, reorder: edit, object_initializer: :itself.to_proc, &generate)
    listview = Gtk::FormDSL::ListView.new(
      self, columns, config, object_initializer,
      create: edit,
      update: edit,
      delete: edit,
      reorder: reorder,
      &generate)
    listview.hexpand = true

    grid = Gtk::Grid.new
    grid.orientation = :vertical
    grid.row_spacing =  6
    grid << (Gtk::Grid.new.tap do |grid|
      grid.column_spacing = 6
      grid << listview << listview.buttons
    end)

    attach_next_to grid, nil, :bottom, 2, 1

    Chainable.new grid
  end

  # 要素を１つ選択させる
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def select(text, key, default = {}, mode: :auto, **kwrest, &block)
    builder = SelectBuilder.new self, text, key, default.merge(kwrest), mode: mode
    block and builder.instance_eval(&block)
    widgets = builder.build

    if widgets.size == 1
      list, = widgets

      attach_next_to list, nil, :bottom, 2, 1

      Chainable.new list
    else
      label, combo = widgets
      label.halign = :start
      label.hexpand = true

      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to combo, label, :right, 1, 1

      Chainable.new combo
    end
  end

  # 要素を複数個選択させる
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def multiselect(text, key, default = {}, &block)
    builder = MultiSelectBuilder.new self, text, key, default
    block and builder.instance_eval(&block)
    list, = builder.build

    attach_next_to list, nil, :bottom, 2, 1

    Chainable.new list
  end

  def keybind(title, config)
    keyconfig = Gtk::KeyConfig.new(title, self[config] || "")
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(title), false, true, 0)
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(keyconfig), true, true, 0)
    keyconfig.change_hook = ->(modify) { self[config] = modify }
    closeup(container)
    container
  end

  # 引数のテキストを表示する。
  def label(text)
    Gtk::Label.new(text).apply do
      self.halign = :start
      self.wrap = true
      self.xalign = 0
    end.tap do |label|
      attach_next_to label, nil, :bottom, 2, 1
    end
  end

  # 引数のテキストを表示する。
  def markup(text)
    Gtk::Label.new.apply do
      self.halign = :start
      self.wrap = true
      self.markup = text
      self.xalign = 0
    end.tap do |label|
      attach_next_to label, nil, :bottom, 2, 1
    end
  end

  # Diva::Model の内容を表示する。
  # 通常はボタンとして描画され、クリックするとopenイベントが発生する。
  # エレメントとして値を更新する機能はない。
  # ==== Args
  # 以下のいずれか
  # [String | Diva::URI] URLを表示する
  # [Diva::Model]
  #   _target.title_ がラベルになる。
  #   _target.icon_ が呼び出せてPhotoModelを返す場合は、それも表示する。
  def link(target)
    case target
    when String, URI, Addressable::URI, Diva::URI
      button = Gtk::Button.new(target.to_s, false)
      button.
        tooltip(target.to_s).
        set_alignment(0.0, 0.5).
        ssc(:clicked, &model_opener(target))
      add button
    when Diva::Model
      button = Gtk::Button.new
      box = Gtk::HBox.new
      if target.respond_to?(:icon)
        icon = Gtk::WebIcon.new(target.icon, 48, 48)
        box.closeup(icon)
      end
      button.
        tooltip(target.title).
        add(box.add(Gtk::Label.new(target.title))).
        ssc(:clicked, &model_opener(target))
      add button
    end
  end

  def native(widget)
    widget.hexpand = true
    attach_next_to widget, nil, :bottom, 2, 1
  end

  # settingsメソッドとSelectから内部的に呼ばれるメソッド。Groupの中に入れるGtkウィジェットを返す。
  # 戻り値は同時にこのmix-inをロードしている必要がある。
  def create_inner_setting
    self.new()
  end

  def method_missing(*args, &block)
    @plugin.__send__(*args, &block)
  end

private

  def build_entry(key)
    entry = Gtk::Entry.new
    entry.text = self[key] || ''
    entry.ssc :changed do
      self[key] = entry.text
      false
    end
    entry
  end

  def about_converter
    Hash.new(ret_nth).merge!(
      logo: -> value {
        case value
        when GdkPixbuf::Pixbuf
          value
        when Diva::Model
          value.pixbuf(width: 48, height: 48)
        else
          Plugin.collect(:photo_filter, value, Pluggaloid::COLLECT).first.pixbuf(width: 48, height: 48) rescue nil
        end
      }
    )
  end
  memoize :about_converter

  def build_font(key)
    s = self[key]
    font = Gtk::FontButton.new(*(s ? [s] : []))
    font.ssc(:font_set) { self[key] = font.font_name }
    font
  end

  def build_color(key)
    a = self[key]

    # migration from Gdk::Color to Gdk::RGBA
    a&.first&.is_a? Integer and a = self[key] = a.map { |i| i.to_f / 65_536 }

    color = Gtk::ColorButton.new(*(a ? [Gdk::RGBA.new(*a)] : []))
    color.ssc(:color_set) { self[key] = color.rgba.to_a[0, 3] }
    color
  end

  def fs_photo_thumbnail(path)
    Plugin.collect(:photo_filter, path, Pluggaloid::COLLECT).first
  end

  def model_opener(model)
    ->(*args) do
      Plugin.call(:open, model)
      true
    end
  end
end

require 'mui/gtk_form_dsl_select'
require 'mui/gtk_form_dsl_multi_select'
require 'mui/gtk_form_dsl_listview'
