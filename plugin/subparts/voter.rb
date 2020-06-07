# frozen_string_literal: true

module Plugin::Subparts
  class Voter < Gtk::Grid
    ICON_SIZE = 24
    SPACING = 3

    def initialize()
      super()

      self.orientation = :horizontal
      self.column_spacing = SPACING

      build
    end

    def icon; end
    def count; end
    def voters_d; end

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
      label.width_request = ICON_SIZE

      self << image << label

      voters_d.next do |voters|
        voters.first(20).each(&method(:add_icon))
        show_all
      end.trap { |err| error err }
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
