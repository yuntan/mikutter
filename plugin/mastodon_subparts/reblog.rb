# frozen_string_literal: true

module Plugin::MastodonSubparts
  class Reblog < Plugin::Subparts::Voter
    def self.instances
      @@instances ||= {}
    end

    def initialize(model)
      super

      self.class.instances[model.uri] = self
    end

    def icon
      ::Skin[:retweet]
    end

    def count
      model.actual_status.reblogs_count
    end

    def voters
      model.actual_status.reblogged_by
    end
  end
end
