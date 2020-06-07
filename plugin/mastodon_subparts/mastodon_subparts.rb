# frozen_string_literal: true

require_relative 'reply'
require_relative 'favorite'
require_relative 'reblog'

Plugin.create :mastodon_subparts do
  psp = Plugin::SubpartsPhoto
  pms = Plugin::MastodonSubparts

  filter_subparts_widgets do |status, yielder|
    status.class == Plugin::Mastodon::Status or next [status, yielder]
    [psp::Photo, pms::Reply, pms::Favorite, pms::Reblog].each do |klass|
      yielder << klass.new(status)
    end
    [status, yielder]
  end

  update_favorite = proc do |_, _, status|
    pms::Favorite.instances[status.uri]&.changed
  end

  on_favorite(&update_favorite)
  on_before_favorite(&update_favorite)
  on_fail_favorite(&update_favorite)
  on_unfavorite(&update_favorite)

  update_share = proc do |_, status|
    pms::Reblog.instances[status.uri]&.changed
  end

  on_share(&update_share)
  on_before_share(&update_share)
  on_fail_share(&update_share)
  on_destroy_share(&update_share)
end
