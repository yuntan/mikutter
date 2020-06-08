# frozen_string_literal: true

module Plugin::MastodonSubparts
  class Reply < Plugin::Subparts::Status
    def initialize(child_model)
      @child_model = child_model

      super()
    end

    def model_d
      Deferred.new do
        +@child_model.replyto_source_d(true) if @child_model.in_reply_to_id
      end
    end
  end
end
