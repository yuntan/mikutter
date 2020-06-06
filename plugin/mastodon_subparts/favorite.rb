# frozen_string_literal: true

module Plugin::MastodonSubparts
  class Favorite < Plugin::Subparts::Voter
    def self.instances
      @@instances ||= {}
    end

    def initialize(model)
      super

      self.class.instances[model.uri] = self
    end

    def icon
      ::Skin[:unfav]
    end

    def count
      model.favorite_count
    end

    def voters
      model.actual_status.favorited_by
    end
  end
end
