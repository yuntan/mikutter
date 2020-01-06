# frozen_string_literal: true

require 'gtk3'

require 'mui/gtk_postbox'
require 'mui/cairo_miracle_painter'

module Plugin::Gtk
=begin rdoc
  投稿ボックスとスクロール可能のリストビューを備えたウィジェット
=end
  class Timeline < Gtk::Grid
    class Row < Gtk::ListBoxRow
      def initialize
        super

        ssc :state_flags_changed do
          selected = (state_flags & Gtk::StateFlags::SELECTED).nonzero?
          if selected
            # TODO
          else
            # TODO
          end
        end
      end
    end

    Delayer.new do
      plugin = Plugin::create :core
      plugin.add_event :message_modified do |model|
        # TODO
      end
      plugin.add_event :destroyed do |models|
        # TODO
      end
    end

    # used for deprecation year and month
    YM = [2019, 10].freeze

    include Enumerable
    extend Gem::Deprecate

    attr_reader :postbox
    attr_reader :listbox

    def initialize(imaginary=nil)
      super()

      self.name = 'timeline'
      self.orientation = :vertical

      @imaginary = imaginary
      @hash = {} # Diva::URI => Row
      @order = ->(m) { m.modified.to_i }
      @postbox = Gtk::Grid.new.tap do |grid|
        grid.orientation = :vertical
      end
      @listbox = Gtk::ListBox.new.tap do |listbox|
        listbox.selection_mode = :multiple
        listbox.set_sort_func do |row1, row2|
          @order.call row1.model <=> (@order.call row2.model)
        end
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

    def active!
      # TODO
      raise NotImplementedError
    end
    alias active active!
    deprecate :active, :active!, *YM

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
      @listbox.remove row if row

      row = Row.new
      row.add ::Gdk::MiraclePainter.new model
      row.show_all
      @listbox.add row
      @hash[model.uri.hash] = row
    end
  end
end
