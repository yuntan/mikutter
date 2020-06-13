# frozen_string_literal: true

require 'mui/gtk_postbox'

module Plugin::Gtk3
=begin rdoc
  投稿ボックスとスクロール可能のリストビューを備えたウィジェット
=end
  class Timeline < Gtk::Grid

    Delayer.new do
      plugin = Plugin::create :core
      plugin.add_event :message_modified do |model|
        notice "TODO message_modified"
      end
      plugin.add_event :destroyed do |models|
        notice "TODO destroyed"
      end
    end

    # used for deprecation year and month
    YM = [2019, 10].freeze

    include Enumerable
    extend Gem::Deprecate

    attr_reader :imaginary
    attr_reader :postbox
    attr_reader :listbox
    attr_accessor :order

    def initialize(imaginary=nil)
      super()

      self.name = 'timeline'
      self.orientation = :vertical

      @imaginary = imaginary
      @hash = {} # Diva::URI => Row
      @order = ->(m) { m.modified.to_i }

      @postbox = Gtk::Grid.new
      @postbox.orientation = :vertical

      @listbox = Gtk::ListBox.new
      @listbox.selection_mode = :single
      @listbox.set_sort_func do |row1, row2|
        (@order.call row2.model) <=> (@order.call row1.model)
      end
      @listbox.ssc :row_selected do
        @imaginary.active!
      end

      add @postbox
      add(Gtk::ScrolledWindow.new.tap do |sw|
        sw.set_policy :never, :automatic
        sw.expand = true
        sw.add @listbox
      end)
    end

    def size
      children.size
    end

    # iterate over _Diva::Model_s
    # implement _Enumerable_
    def each(&blk)
      foreach { |row| blk.call row.child.model }
    end

    def include?(model)
      ! @hash[model.uri.hash].nil?
    end

    def destroyed?
      # TODO
      false
    end

    def active_models
      [@listbox.selected_row&.model]
    end

    def push!(model)
      check_and_push! model
    end
    alias modified push!
    deprecate :modified, :push!, *YM
    alias favorite push!
    deprecate :favorite, :push!, *YM
    alias unfavorite push!
    deprecate :unfavorite, :push!, *YM

    def push_all!(models)
      models.each(&method(:check_and_push!))
    end
    alias block_add_all push_all!
    deprecate :block_add_all, :push_all!, *YM
    alias remove_if_exists_all push_all!
    deprecate :remove_if_exists_all, :push_all!, *YM
    alias add_retweets push_all!
    deprecate :add_retweets, :push_all!, *YM

    def clear!
      # TODO
      raise NotImplementedError
    end
    alias clear clear!
    deprecate :clear, :clear!, *YM

  private

    def check_and_push!(model)
      row = @hash[model.uri.hash]
      row and @listbox.remove row

      row = MiraclePainter.new model
      row.show_all
      @listbox.add row
      @hash[model.uri.hash] = row
    end
  end
end
