# frozen_string_literal: true

module Plugin::MastodonSubparts
  class Reblog < Plugin::Subparts::Voter
    def self.instances
      @@instances ||= {}
    end

    def initialize(model)
      @model = model

      super()

      self.class.instances[model.uri] = self
    end

    attr_reader :model

    def icon
      ::Skin[:retweet]
    end

    def count
      model.actual_status.reblogs_count
    end

    def voters_d
      model.actual_status.reblogged_by_d
    end
  end
end
