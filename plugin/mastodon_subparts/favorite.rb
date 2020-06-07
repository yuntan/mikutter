# frozen_string_literal: true

module Plugin::MastodonSubparts
  class Favorite < Plugin::Subparts::Voter
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
      ::Skin[:unfav]
    end

    def count
      model.favourites_count
    end

    def voters_d
      model.favourited_by_d
    end
  end
end
