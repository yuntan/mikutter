# frozen_string_literal: true

module Plugin::Subparts
  class Voter < Gtk::Grid
    ICON_SIZE = 24
    SPACING = 3

    def initialize(model)
      super()

      self.orientation = :horizontal
      self.column_spacing = SPACING

      @model = model

      build
    end

    attr_reader :model

    def icon; end
    def count; end
    def voters; end

    def changed
      children.each { |child| remove child }
      build
    end

  private

    def build
      count.zero? and return

      image = Gtk::Image.new
      size = ICON_SIZE
      image.pixbuf = icon.load_pixbuf width: size, height: size do |pb|
        image.pixbuf = pb
      end

      label = Gtk::Label.new count.to_s

      self << image << label

      voters.each(&method(:add_icon))
    end

    def add_icon(voter)
      image = Gtk::Image.new
      image.tooltip_text = voter.name
      size = ICON_SIZE
      image.pixbuf = voter.icon.load_pixbuf width: size, height: size do |pb|
        image.pixbuf = pb
      end

      box = Gtk::EventBox.new
      em = Gdk::EventMask
      box.set_events em::BUTTON_RELEASE_MASK | em::ENTER_NOTIFY_MASK
      box.ssc :button_release_event do |_, ev|
        ev.button == Gtk::BUTTON_PRIMARY or next

        Plugin.call :open, voter
      end
      pointer = Gdk::Cursor.new 'pointer'
      box.ssc :enter_notify_event do
        box.window.cursor = pointer
      end

      self << (box << image)
    end
  end
end
