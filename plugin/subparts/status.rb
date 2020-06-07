# frozen_string_literal: true

module Plugin::Subparts
  class Status < Gtk::ListBox
    def initialize()
      super()
      self.selection_mode = :none

      model_d.next do |model|
        @model = model
        if model
          self << build_row
          show_all
        end
      end.trap { |err| error err }
    end

    attr_reader :model

    def model_d; end

    def build_row
      Plugin::Gtk3::MiraclePainter.new model, as_subparts: true
    end
  end
end
