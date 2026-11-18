# Page 2

A personal news reader for Mac, iPad, and iPhone. It pulls RSS feeds, clusters
related articles into stories, labels each outlet left, center, or right, and
highlights blindspots where one side barely covered a story.

## Install on Mac

With Homebrew:

```sh
brew tap jayclark5150/tap
brew install --cask page2
```

Or download `Page2-0.2.0.dmg` from the
[latest release](https://github.com/jayclark5150/page2/releases/latest), open it,
and drag Page 2 into Applications. See First launch below to get past Gatekeeper.

For iPad and iPhone, build from source with Xcode. See the install steps further
down.

## Features

- Reads RSS 2.0 and Atom feeds from a curated list of outlets.
- Clusters related articles into stories with hand written TF-IDF and cosine
  similarity. No machine learning frameworks.
- Bias labels come from a hand curated JSON source list in `Page2/Resources`.
- Stories view with a per story bias bar, search, and a bias filter.
- Story detail groups coverage under Left, Center, and Right.
- Blindspot view for stories where one side barely reported.
- Sources view to enable or disable outlets.
- Automatic refresh on launch and on a timer, plus manual refresh with Cmd R.
- Settings for refresh interval, clustering threshold, and article age limit.

## Requirements

- macOS 14 or newer, or iPadOS or iOS 17 or newer
- Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Page 2 is a single multiplatform app. The same code runs on Mac, iPad, and
iPhone. On Mac it uses a resizable window and the menu bar. On iPad and iPhone
the sidebar collapses into navigation and Settings opens as a sheet.

## Build and run

The Xcode project is generated from `project.yml`. Do not hand edit the
`.xcodeproj`. After adding or moving source files, run `xcodegen` again.

```sh
brew install xcodegen
xcodegen

# Mac
xcodebuild -scheme Page2 -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -scheme Page2 -destination 'generic/platform=iOS Simulator' build
```

Or open `Page2.xcodeproj` in Xcode and run.

## Installing on an iPhone or iPad without a paid developer account

A free Apple ID is enough to run the app on your own device for 7 days at a time.
The project is wired to a personal team for iOS, so Xcode creates and renews the
provisioning profile automatically.

1. Open `Page2.xcodeproj` in Xcode.
2. Plug in the device and pick it as the run destination.
3. Press Run. Xcode creates the profile and installs the app.
4. On the device, go to Settings, General, VPN and Device Management, and trust
   your developer certificate.

The free provisioning profile expires after 7 days, so press Run again from Xcode
when the app stops opening. A paid Apple Developer account removes the 7 day limit.

If you are not Jay, change `DEVELOPMENT_TEAM` in `project.yml` to your own team id
(Xcode, Settings, Accounts) and run `xcodegen`, or just set your team in Signing
and Capabilities.

## First launch

The app is ad-hoc signed with no Apple Developer ID, so macOS Gatekeeper blocks
it the first time. Trust it either way:

- In System Settings: open the app once, then go to System Settings, Privacy and
  Security, scroll to the message about Page 2, and click Open Anyway.
- In the terminal: `xattr -dr com.apple.quarantine /Applications/Page2.app`

## Test

```sh
xcodebuild -scheme Page2 -destination 'platform=macOS' test
```

The suite covers the feed parser, the clusterer, and the blindspot rule.

## Keyboard shortcuts

- Cmd R: refresh
- Cmd 1, Cmd 2, Cmd 3: Stories, Blindspot, Sources
- Cmd comma: Settings

## Editing the source list

`Page2/Resources/sources.json` holds the outlets and their bias labels. Each
entry has an editable `note` field. The bias labels are judgments to review and
change. On launch the app inserts or updates outlets by slug and never
overwrites an enabled or disabled choice you have made.

## Notes

- Bias labels do not copy any licensed rating data. They are hand curated.
- Clustering similarity is corpus dependent. If stories look under grouped on a
  light news day, lower the threshold in Settings.
