# -*- coding: utf-8 -*-
miquire :mui, 'form_dsl', 'form_dsl_select', 'form_dsl_multi_select'

module Plugin::Gtk
  module DialogWindow
    # ダイアログを開く。このメソッドを直接利用せずに、Pluginのdialog DSLを利用すること。
    # ==== Args
    # [title:] ダイアログのタイトルバーに表示する内容(String)
    # [promise:] 入力が完了・中断された時に呼ばれるDeferedオブジェクト
    # [plugin:] 呼び出し元のPluggaloid Plugin
    # [default:] エレメントのデフォルト値。{キー: デフォルト値}のようなHash
    # [&proc] DSLブロック
    # ==== Return
    # 作成されたDialogのインスタンス
    module_function def open(**kw, &p)
      builder = Gtk::Builder.new
      s = (Pathname(__FILE__).dirname / 'dialog.glade').to_s
      builder.add_from_file s
      dialog = builder.get_object :dialog
      dialog.extend self
      dialog.init builder: builder, **kw, &p
      dialog.show_all
      dialog
    end

    def initialize(title:, parent:, promise:, plugin:, default:, &proc)
      super(title: title, parent: parent, flags: :modal, buttons: [[Gtk::Stock::OK, :ok], [Gtk::Stock::CANCEL, :cancel]])
      set_property :use_header_bar, 1
      @plugin = plugin
      @container = DialogContainer.new(plugin, default.to_h.dup, &proc)
      @container.error_observer = self
      @promise = promise
      set_size_request(640, 480)
      set_window_position :center
      vbox.pack_start(@container)
      register_response_listener
      run_container
    end

    def init(title:, parent:, promise:, plugin:, builder:, default:, &p)
      @plugin = plugin
      @promise = promise

      self.title = title
      self.transient_for = parent

      @container = DialogContainer.new(plugin, default.to_h.dup, &proc)
      @container.error_observer = self
      child.add @container
      @btn_ok = builder.get_object :btn_ok
      register_response_listener
      run_container
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
            run_container
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
        case response
        when Gtk::Dialog::RESPONSE_OK
          case @container.state
          when DialogContainer::STATE_WAIT
            run_container(Response::Ok.new(@container)).next do
              # 確認画面ではボタンのテキストを「追加」に変更
              @btn_ok.label = 'gtk-add' if @container.state == DialogContainer::STATE_EXIT
            end
          when DialogContainer::STATE_EXIT
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
        action_area.sensitive = state == Gtk::STATE_INSENSITIVE
        false
      end
    end

    def run_container(res=nil)
      @container.run(res)
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
  end

  class DialogContainer < Gtk::Box
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

    def initialize(plugin, default=Hash.new, &proc)
      @plugin = plugin
      @values = default
      @proc = proc
      reset
      super(:vertical){}
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
