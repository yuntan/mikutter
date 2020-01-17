# -*- coding: utf-8 -*-
# ／(^o^)＼

require 'environment'
require 'mui/gtk_web_image_loader'
require 'serialthread'
require 'skin'

require 'gtk3'
require 'observer'

# Web上の画像をレンダリングできる。
# レンダリング中は読み込み中の代替イメージが表示され、ロードが終了したら指定された画像が表示される。
# メモリキャッシュ、ストレージキャッシュがついてる。
module Gtk
  class WebIcon < Image

    DEFAULT_RECTANGLE = Gdk::Rectangle.new(0, 0, 48, 48)

    include Observable

    # ==== Args
    # [url] 画像のURLもしくはパス(String)
    # [rect] 画像のサイズ(Gdk::Rectangle) または幅(px)
    # [height] 画像の高さ(px)
    def initialize(url, rect = DEFAULT_RECTANGLE, height = nil)
      rect = Gdk::Rectangle.new(0, 0, rect, height) if height
      case url
      when Diva::Model
        super(pixbuf: load_model(url, rect))
      when GdkPixbuf::Pixbuf
        super(pixbuf: url)
      else
        photo = Enumerator.new{|y|
          Plugin.filtering(:photo_filter, url, y)
        }.first
        super(pixbuf: load_model(photo || Skin[:notfound], rect))
      end
    end

    def load_model(photo, rect)
      photo.load_pixbuf(width: Gdk.scale(rect.width), height: Gdk.scale(rect.height)){|pb|
        update_pixbuf(pb)
      }
    end

    def update_pixbuf(pixbuf)
      unless destroyed?
        self.pixbuf = pixbuf
        self.changed
        self.notify_observers
      end
    end
  end
end
