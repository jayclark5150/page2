#!/bin/bash
# Release Page 2 0.5.2: rebuild, test, make the dmg, push to GitHub, update the brew cask.
# Stops at the first failure. Nothing is pushed unless the build and tests pass.
set -euo pipefail

VER="0.5.2"
cd "/Volumes/Projects/Page2App"

echo "== Free disk space"
df -h . | tail -1

echo "== Regenerate Xcode project"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen

echo "== Run tests"
xcodebuild -scheme Page2 -destination 'platform=macOS' -derivedDataPath build test | tail -15

echo "== Release build"
xcodebuild -scheme Page2 -configuration Release -destination 'platform=macOS' -derivedDataPath build build | tail -5
APP="build/Build/Products/Release/Page2.app"
test -d "$APP"
echo "Built version: $(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)"

echo "== Make dmg"
rm -rf build/dmg "Page2-$VER.dmg"
mkdir build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "Page 2" -srcfolder build/dmg -ov -format UDZO "Page2-$VER.dmg"
SHA=$(shasum -a 256 "Page2-$VER.dmg" | awk '{print $1}')
echo "sha256: $SHA"

echo "== Commit, tag, push"
git add -u
git status --short
git commit -m "Release $VER: drop CNN's dead feed, remove publish time from Stories row"
git tag "v$VER"
git push origin main
git push origin "v$VER"

echo "== GitHub release"
if command -v gh >/dev/null; then
  gh release create "v$VER" "Page2-$VER.dmg" --repo jayclark5150/page2 \
    --title "Page 2 $VER" \
    --notes "Removes CNN from the starter list (its only public feed is cleartext http that the sandbox blocks) and removes the publish date and time from the Stories row so it fits the iPhone layout."
else
  echo "gh is not installed. Create the v$VER release by hand and attach Page2-$VER.dmg."
  exit 1
fi

echo "== Homebrew cask"
TAP="$(brew --repository jayclark5150/tap)"
CASK="$TAP/Casks/page2.rb"
test -f "$CASK"
sed -i '' -E "s/^( *version )\"[^\"]*\"/\1\"$VER\"/; s/^( *sha256 )\"[^\"]*\"/\1\"$SHA\"/" "$CASK"
git -C "$TAP" diff
git -C "$TAP" add Casks/page2.rb
git -C "$TAP" commit -m "page2 $VER"
git -C "$TAP" push

echo "== Done: Page 2 $VER released"
