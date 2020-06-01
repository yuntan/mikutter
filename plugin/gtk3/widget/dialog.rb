# -*- coding: utf-8 -*-

require 'mui/gtk_form_dsl'
require 'mui/gtk_form_dsl_multi_select'
require 'mui/gtk_form_dsl_select'

module Plugin::Gtk3
  module Dialog
    # ダイアログを開く。このメソッドを直接利用せずに、Pluginのdialog DSLを利用すること。
    # ==== Args
    # [title:] ダイアログのタイトルバーに表示する内容(String)
    # [parent:] 親ウィンドウ．ダイアログはモーダルとして開かれる．
    # [promise:] 入力が完了・中断された時に呼ばれるDeferedオブジェクト
    # [plugin:] 呼び出し元のPluggaloid Plugin
    # [default:] エレメントのデフォルト値。{キー: デフォルト値}のようなHash
    # [&proc] DSLブロック
    # ==== Return
    # 作成されたDialogのインスタンス
    module_function def open(**kw, &p)
      # dialog.gladeからUIを構築
      builder = Gtk::Builder.new
      s = (Pathname(__FILE__).dirname / 'dialog.glade').to_s
      builder.add_from_file s
      dialog = builder.get_object :dialog
      dialog.extend self
      dialog.init builder: builder, **kw, &p
      dialog.show_all
      dialog
    end

    def init(title:, parent:, promise:, plugin:, builder:, default:, &p)
      @plugin = plugin
      @promise = promise

      self.title = title
      self.transient_for = parent

      @container = Container.new(plugin, default.to_h.dup, &p)
      @container.error_observer = self
      child.add @container
      @btn_ok = builder.get_object :btn_ok
      register_response_listener
      @container.run
    end

    def on_abort(err)
      if err.is_a?(String)
        Delayer.new do
          set_sensitive(false)
          alert = Gtk::MessageDialog.new(nil,
                                         Gtk::Dialog::DESTROY_WITH_PARENT,
                                         Gtk::MessageDialog::ERROR,
                                         Gtk::MessageDialog::BUTTONS_CLOSE,
                                         err)
          alert.ssc(:response){|widget| widget.destroy; false }
          alert.ssc(:destroy) do
            set_sensitive(true)
            @container.reset
            @container.run
            false
          end
          alert.show_all
        end
      else
        Delayer.new do
          @promise.fail(err) if @promise
          @promise = nil
          destroy
        end
      end
    end

    private

    def register_response_listener
      ssc(:response) do |widget, response|
        if Gtk::ResponseType::OK == response
          case @container.state
          when Container::STATE_WAIT
            @container.run(Response::Ok.new(@container)).next do
              # 確認画面ではボタンのテキストを「追加」に変更
              @container.state == Container::STATE_EXIT \
                and (@btn_ok.label = 'gtk-add')
            end
          when Container::STATE_EXIT
            @promise.call(Response::Ok.new(@container)) if @promise
            @promise = nil
            destroy
          end
        else
          @promise.fail(Response::Cancel.new(@container)) if @promise
          @promise = nil
          destroy
        end
        true
      end
      ssc(:destroy) do
        @promise.fail(Response::Cancel.new(@container)) if @promise
        @promise = nil
        false
      end
      @container.ssc(:state_changed) do |widget, state|
        action_area.sensitive = state == :insensitive
        false
      end
    end

    module Response
      class Base
        attr_reader :result

        def initialize(values)
          @values = values.to_h.freeze
          @result = values.result_of_proc
        end

        def [](k)
          @values[k.to_sym]
        end

        def to_h
          @values.to_h
        end
      end

      class Ok < Base
        def ok? ; true end
        def state ; :ok end
      end

      class Cancel < Base
        def ok? ; false end
        def state ; :cancel end
      end

      class Close < Base
        def ok? ; false end
        def state ; :close end
      end
    end

    class Container < Gtk::Grid
      EXIT = :exit
      AWAIT = :await

      STATE_INIT = :dialog_state_init
      STATE_RUN = :dialog_state_run
      STATE_EXIT = :dialog_state_exit
      STATE_WAIT = :dialog_state_wait
      STATE_AWAIT = :dialog_state_await

      include Gtk::FormDSL

      attr_reader :state, :result_of_proc, :awaiting_deferred
      attr_accessor :error_observer

      # dialog DSLから利用するメソッド。
      # dialogウィンドウのエレメントの配置を、ユーザが次へボタンを押すまで中断する。
      # 次へボタンが押されたら、 その時点で各エレメントに入力された内容を格納した
      # Plugin::Gtk::DialogWindow::Response::Ok のインスタンスを返す
      def await_input
        Fiber.yield
      end

      # dialog DSLから利用するメソッド。
      # 初期値を動的に設定するためのメソッド。
      # {エレメントのキー: 値} のように書くことで、複数同時に設定できる。
      # 既に置かれたエレメントの内容がこのメソッドによって書き換わることはないので、
      # エレメントを配置する前に呼び出す必要がある。
      def set_value(v={})
        @values.merge!(v)
      end

      # dialog DSLから利用するメソッド。
      # Deferredを受け取り、その処理が終わるまで処理を止める。
      # 処理が終わると、deferの結果を返す。処理が失敗していると、
      # ダイアログウィンドウを閉じ、dialog DSLのtrapブロックを呼ぶ。
      def await(defer)
        Fiber.yield(AWAIT, defer)
      end

      def create_inner_setting
        self.class.new(@plugin, @values)
      end

      def initialize(plugin, default=Hash.new, &p)
        @plugin = plugin
        @values = default
        @proc = p
        reset

        super() {}
        self.margin = 30
        self.row_spacing = self.column_spacing = 12
      end

      def run(response=nil)
        Deferred.new do
          case state
          when STATE_INIT
            @fiber = Fiber.new do
              @result_of_proc = instance_eval(&@proc)
              if @result_of_proc.is_a? Delayer::Deferred::Deferredable::Awaitable
                @result_of_proc = await(@result_of_proc)
              end
              EXIT
            end
            resume(response)
          when STATE_WAIT
            children.each(&method(:remove))
            resume(response)
          when STATE_AWAIT
            resume(response)
          end
        end.trap do |err|
          error err.message
          $stderr.puts err.backtrace
        end
      end

      def resume(response)
        @state = STATE_RUN
        result, *args = @fiber.resume(response)
        set_sensitive(true)
        show_all
        case result
        when EXIT
          @state = STATE_EXIT
        when AWAIT
          @state = STATE_AWAIT
          @awaiting_deferred, = *args
          set_sensitive(false)
          @awaiting_deferred.next{|deferred_result|
            run(deferred_result)
          }.trap{|err|
            error err.message
            $stderr.puts err.backtrace

            @error_observer.on_abort(err) if @error_observer
          }
        else
          @state = STATE_WAIT
        end
      end

      def [](key)
        @values[key.to_sym]
      end

      def []=(key, value)
        @values[key.to_sym] = value
      end

      def reset
        @state = STATE_INIT
        self
      end

      def to_h
        @values.dup
      end
    end
  end
end
