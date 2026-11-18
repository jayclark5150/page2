# Page 2

A personal macOS news reader in the style of Ground News. It pulls RSS feeds,
clusters related articles into stories, labels each outlet left, center, or
right, and highlights blindspots where one side barely covered a story.

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

- macOS 14 or newer
- Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build and run

The Xcode project is generated from `project.yml`. Do not hand edit the
`.xcodeproj`. After adding or moving source files, run `xcodegen` again.

```sh
brew install xcodegen
xcodegen
xcodebuild -scheme Page2 -destination 'platform=macOS' build
```

Or open `Page2.xcodeproj` in Xcode and run.

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
