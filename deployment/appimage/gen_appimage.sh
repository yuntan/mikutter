#!/bin/bash
set -Ceu
shopt -s globstar

########################################################################
# AppImage generator script for Ubuntu Trusty 16.04
# maintained by Yuto Tokunaga <yuntan.sub1@gmail.com>
# For more information, see http://appimage.org/
########################################################################

REPO=$GITHUB_WORKSPACE

echo "--> get mikutter source"
git --git-dir=$REPO/.git/ archive --format=tar --prefix=mikutter/ HEAD | tar xf -

BUILD_DIR="$PWD"/mikutter
set +u
[[ -z "$APPDIR" ]] && APPDIR="$PWD"/AppDir
[[ -z "$ARCH" ]] && export ARCH="$(arch)"
set -u
APP=mikutter
VERSION=$(git -C "$REPO" describe --tags --abbrev=0 || date +%Y-%m-%d-$(git rev-parse --short HEAD))

echo "--> install gems"
pushd "$BUILD_DIR"
export GEM_PATH=$APPDIR/usr/lib/ruby/gems/2.6.0
# do not install test group
$APPDIR/usr/bin/bundle install --path=vendor/bundle --without=test --jobs=2
$APPDIR/usr/bin/bundle install # actually build gems

popd

echo "--> copy mikutter"
mkdir -p $APPDIR/app
cp -av "$BUILD_DIR"/{.bundle,core,plugin,vendor,mikutter.rb,Gemfile{,.lock},LICENSE,README} $APPDIR/app

echo "--> copy Typelibs for gobject-introspection gem"
mkdir -p $APPDIR/usr/lib/girepository-1.0
cp -av /usr/lib/girepository-1.0/* /usr/lib/x86_64-linux-gnu/girepository-1.0/* $APPDIR/usr/lib/girepository-1.0

echo "--> remove unused files"
rm -vrf $APPDIR/usr/share $APPDIR/usr/include $APPDIR/usr/lib/{pkgconfig,debug}
rm -vrf $APPDIR/usr/lib/ruby/gems/2.6.0/cache $APPDIR/app/vendor/bundle/ruby/2.6.0/cache
rm -v $APPDIR/**/*.{a,o}

# echo "--> patch away absolute paths"
# for gobject-introspection gem
# find usr/lib -name libgirepository-1.0.so.1 -exec sed -i -e 's|/usr/lib/girepository-1.0|.////lib/girepository-1.0|g' {} \;

# remove libssl and libcrypto
# see https://github.com/AppImage/AppImageKit/wiki/Desktop-Linux-Platform-Issues#openssl
# blacklist="libssl.so.1 libssl.so.1.0.0 libcrypto.so.1 libcrypto.so.1.0.0"
# blacklist=
# remove libharfbuzz and it's dependencies,
# see https://github.com/AppImage/AppImageKit/issues/454
# blacklist=$blacklist" libharfbuzz.so.0 libfreetype.so.6"
# for f in $blacklist; do
#   found="$(find . -name "$f" -not -path "./usr/optional/*")"
#   for f2 in $found; do
#     rm -vf "$f2" "$(readlink -f "$f2")"
#   done
# done

# prepare files for linuxdeploy
cp "$BUILD_DIR"/core/skin/data/icon.png mikutter.png
cp "$BUILD_DIR"/deployment/appimage/{AppRun,mikutter.desktop} .
chmod +x AppRun

echo "--> get linuxdeploy"
wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

export OUTPUT=$OUTDIR/$APP-$VERSION-$ARCH.AppImage

./linuxdeploy-x86_64.AppImage --appimage-extract

./squashfs-root/AppRun \
  --appdir $APPDIR \
  --icon-file mikutter.png \
  --desktop-file mikutter.desktop \
  --custom-apprun AppRun \
  --output appimage

echo "--> generated $OUTPUT"

echo '==> finished'
