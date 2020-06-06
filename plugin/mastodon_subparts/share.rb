# frozen_string_literal: true

module Plugin::MastodonSubparts
  class Share < Plugin::Subparts::Voter
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
      model.retweet_count
    end

    def voters
      model.retweeted_by
    end
  end
end
