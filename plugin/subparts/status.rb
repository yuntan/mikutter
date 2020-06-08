# frozen_string_literal: true

module Plugin::Subparts
  class Status < Gtk::ListBox
    def initialize()
      super()
      self.selection_mode = :none

      provider = Gtk::CssProvider.new
      provider.load_from_data 'list { background: transparent; }'
      style_context.add_provider provider

      model_d.next do |model|
        next unless model

        self << build_row(model)
        show_all
      end.trap { |err| error err }
    end

    def model_d; end

  private

    def build_row(model)
      row = Plugin::Gtk3::MiraclePainter.new model, as_subparts: true
      ssc :row_activated do
        Plugin.call :open, model
      end
      row
    end
  end
end
