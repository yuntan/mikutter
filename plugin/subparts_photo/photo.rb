# frozen_string_literal: true

module Plugin::SubpartsPhoto
  class Photo < Gtk::ScrolledWindow
    SPACING = 6

    def initialize(model)
      super()

      @model = model

      build
    end

    attr_reader :model

  private

    def build
      grid = Gtk::Grid.new
      grid.column_spacing = SPACING

      score.select do |note|
        note.respond_to? :reference or next
        note.reference.is_a? Plugin::Photo::Photo
      end
           .each do |note|
        photo = note.reference
        image = Gtk::Image.new
        height = UserConfig[:subparts_photo_height]
        image.pixbuf = photo.load_pixbuf(width: height * 3, height: height) do |pb|
          image.pixbuf = pb
        end

        box = Gtk::EventBox.new
        box << image
        em = Gdk::EventMask
        box.set_events em::BUTTON_RELEASE_MASK |
                       em::ENTER_NOTIFY_MASK |
                       em::LEAVE_NOTIFY_MASK
        box.ssc :button_release_event do |_, ev|
          ev.button == Gdk::BUTTON_PRIMARY or next false
          Plugin.call :open, photo
          true
        end
        pointer = Gdk::Cursor.new 'pointer'
        box.ssc :enter_notify_event do
          box.window.cursor = pointer
        end

        grid << box
      end

      self.set_policy :automatic, :never
      self << grid
    end

    def score
      @score ||= Plugin[:subparts_photo].score_of model
    end
  end
end
