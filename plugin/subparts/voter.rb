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

      sw = Gtk::ScrolledWindow.new
      sw.set_policy :external, :never
      sw.hexpand = true

      grid = Gtk::Grid.new

      self << image << label << (sw << grid)

      voters_d.next do |voters|
        voters.first(20).each { |voter| grid << build_icon(voter) }
        show_all
      end.trap { |err| error err }
    end

    def build_icon(voter)
      image = Gtk::Image.new
      image.tooltip_text = voter.name
      size = ICON_SIZE
      image.pixbuf = voter.icon.load_pixbuf width: size, height: size do |pb|
        image.pixbuf = pb
      end

      box = Gtk::EventBox.new
      box.visible_window = false
      em = Gdk::EventMask
      box.events = em::BUTTON_RELEASE_MASK | em::ENTER_NOTIFY_MASK
      box.ssc :button_release_event do |_, ev|
        ev.button == Gtk::BUTTON_PRIMARY or next

        Plugin.call :open, voter
      end
      pointer = Gdk::Cursor.new 'pointer'
      box.ssc :enter_notify_event do
        box.window.cursor = pointer
      end

      box << image
    end
  end
end
