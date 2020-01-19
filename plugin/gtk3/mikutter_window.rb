# -*- coding: utf-8 -*-

require 'pathname'

require_relative 'toolbar_generator'
require_relative 'world_shifter'

# PostBoxや複数のペインを持つWindow
module Plugin::Gtk3
  module MikutterWindow

    attr_reader :panes, :statusbar

    module_function def open(imaginally, plugin)
      # Gtk::Builderで生成したGtk::Windowに特異メソッドを生やす
      builder = Gtk::Builder.new
      s = (Pathname(__FILE__).dirname / 'mikutter_window.glade').to_s
      builder.add_from_file s
      window = builder.get_object 'window'
      window.extend self
      window.init imaginally, plugin, builder
      window
    end

    def init(imaginally, plugin, builder)
      type_strict plugin => Plugin
      @imaginally = imaginally
      @plugin = plugin

      @container = builder.get_object 'container'
      @panes = builder.get_object 'panes'
      @postboxes = builder.get_object 'postboxes'
      @statusbar = builder.get_object 'statusbar'
      context_id = @statusbar.get_context_id('system')
      status_message = @plugin._('Statusbar default message')
      @statusbar.push(context_id, status_message)
      status_button_container = builder.get_object 'status_button_container'
      infrate_status_button status_button_container
      header = builder.get_object 'header'
      header.attach(WorldShifter.new, 0, 0, 1, 1)

      Plugin[:gtk3].on_userconfig_modify do |key, newval|
        key == :postbox_visibility and refresh end
      Plugin[:gtk3].on_world_after_created do |new_world|
        refresh end
      Plugin[:gtk3].on_world_destroy do |deleted_world|
        refresh end
    end

    def add_postbox(i_postbox)
      options = {postboxstorage: @postboxes, delegate_other: true}.merge(i_postbox.options||{})
      if options[:delegate_other]
        i_window = i_postbox.ancestor_of(Plugin::GUI::Window)
        options[:delegate_other] = postbox_delegation_generator(i_window) end
      postbox = Gtk::PostBox.new(options)
      @postboxes.add postbox
      set_focus(postbox.post) unless options[:delegated_by]
      postbox.no_show_all = false
      postbox.show_all if visible?
      postbox end

    private

    def postbox_delegation_generator(window)
      ->(params) do
        postbox = Plugin::GUI::Postbox.instance
        postbox.options = params
        window << postbox end end

    def refresh
      @postboxes.children.each(&(visible? ? :show_all : :hide))
    end

    # ステータスバーに表示するWindowレベルのボタンを _container_ にpackする。
    # 返された時点では空で、後からボタンが入る(showメソッドは自動的に呼ばれる)。
    # ==== Args
    # [container] packするコンテナ
    # ==== Return
    # container
    def infrate_status_button(container)
      current_world, = Plugin.filtering(:world_current, nil)
      ToolbarGenerator.generate(
        container,
        Plugin::GUI::Event.new(
          event: :window_toolbar,
          widget: @imaginally,
          messages: [],
          world: current_world
        ),
        :window
      )
    end

    def visible?
      case UserConfig[:postbox_visibility]
      when :always
        true
      when :auto
        !!Enumerator.new{|y| Plugin.filtering(:worlds, y) }.first
      else
        false
      end
    end

  end
end
