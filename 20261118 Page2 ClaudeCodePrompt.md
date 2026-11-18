# Build Page 2 (macOS news app)

You are building Page 2, a personal macOS app for one user (Jay). It works like Ground News: it pulls articles from RSS feeds, groups related articles into story clusters, labels each outlet as left, center, or right, and has a Blindspot view for stories that one side barely covered.

## Locked decisions
- Native SwiftUI, macOS 14 or newer, SwiftData for storage. No third-party dependencies unless I approve one.
- Bundle ID: com.jayclark.page2. GitHub repo: page2 under jayclark5150.
- Clustering starts with TF-IDF and cosine similarity on titles and summaries. Implement it by hand in Swift, no ML frameworks for v1.
- Bias labels come only from my own hand-curated JSON source list. Do not copy, import, or imitate licensed rating data from AllSides, Media Bias/Fact Check, or Ad Fontes Media.
- Planning milestones: Feed Reader, Story Clustering, Bias View, Polish.

## Current state (already done, do not redo)
Project folder: /Users/jayclark/Documents/Page 2 App
- project.yml (XcodeGen) generates Page2.xcodeproj. After adding or moving any source file, run `xcodegen` in the project folder. Never hand-edit the .xcodeproj.
- Page2/Page2App.swift with `.modelContainer(for: [Source.self, Article.self, Story.self])`
- Page2/ContentView.swift (placeholder)
- Page2/Models/Bias.swift (enum left, center, right)
- Page2/Models/Source.swift (slug unique, name, feedURLString, siteURLString, biasRaw with computed `bias`, isEnabled, lastFetchedAt, articles cascade)
- Page2/Models/Article.swift (link unique, title, summary, publishedAt, fetchedAt, source, story)
- Page2/Models/Story.swift (id unique, headline, createdAt, updatedAt, articles nullify, `outletCount(for:)`, `totalOutletCount`)
- App Sandbox is on with outgoing network connections allowed.
Read these files first and extend them rather than rewriting them. If you change a model, say why.

## Milestone 1: Feed Reader
1. `Page2/Resources/sources.json`: a starter list of about 20 well-known US outlets across the spectrum, each with slug, name, feedURL, siteURL, bias (left, center, or right). Use RSS URLs you are confident are real and public. These are my judgments to review, so add a short `note` field per outlet that I can edit, and flag any feed URL you could not verify.
2. `SourceSeeder`: loads sources.json from the bundle and inserts or updates `Source` records by slug. Never overwrite a user's isEnabled choice.
3. `FeedParser`: XMLParser based, supports RSS 2.0 and Atom. Extract title, link, summary or description, and published date (handle RFC 822 and ISO 8601). Strip HTML tags and decode entities from summaries.
4. `FeedFetcher`: async URLSession, fetches all enabled sources concurrently with a sane limit, timeouts, and per-source error capture. Dedupe by article link. Drop articles older than 7 days.
5. UI: NavigationSplitView with a sidebar (Stories, Blindspot, Sources) and an article list. For now the Stories item shows recent articles with outlet name and a bias chip. A Refresh toolbar button and Cmd+R trigger a fetch. A Sources screen lists outlets with an enable toggle and last fetched time.
6. Unit tests for FeedParser using small RSS and Atom fixtures.

## Milestone 2: Story Clustering
1. `Tokenizer`: lowercase, split on non-letters and digits, remove English stopwords, light stemming or none (recommend one and say why), keep numbers and capitalized names meaningful.
2. `TFIDFClusterer`: build TF-IDF vectors from title (weighted 2x) plus summary, cosine similarity, a configurable threshold (start near 0.35 and expose it as a constant), only compare articles published within 72 hours of each other.
3. Clustering is incremental: new articles join an existing Story if they clear the threshold against the story centroid, otherwise they start a new Story. Never put two articles from the same source in a story as separate coverage points unless they are clearly distinct pieces (that is fine, just count outlets distinctly).
4. Story headline: pick the title of the article closest to the centroid. Update `updatedAt` when articles join.
5. Run clustering after each fetch off the main actor, then save.
6. Unit tests with hand-made fixtures: same event from several outlets clusters together, unrelated stories stay apart, threshold edge cases. Report the numbers you saw.

## Milestone 3: Bias View
1. Story list rows show headline, outlet count, and a three-segment bar (left, center, right) sized by distinct outlet counts.
2. Story detail groups articles under Left, Center, and Right headers, each article opening in the default browser.
3. Blindspot view: stories with at least 4 distinct outlets where one side has zero or under 10 percent of the coverage while another side has most of it. Label each as "Blindspot: left", "Blindspot: right" or similar based on which side missed it. Put the thresholds in one settings struct.
4. Filters: bias filter and a search field on the Stories list.

## Milestone 4: Polish
Automatic refresh on a timer and on launch, a Settings window (refresh interval, clustering threshold, article age limit), empty and error states, a refresh progress indicator, keyboard shortcuts, sensible window sizing and state restoration, a placeholder app icon, and a README with build steps.

## How to work
- Work one milestone at a time. After each milestone: run `xcodegen`, build with `xcodebuild -scheme Page2 -destination 'platform=macOS' build`, run the tests, fix failures, make a git commit with a clear message, then stop and give me a short summary and wait for my go-ahead. Do not push to GitHub unless I ask.
- Inside a milestone, do the numbered tasks in order and keep each file complete, not fragments.
- If a choice has a real tradeoff, state it in one or two sentences, recommend one option, and proceed with the recommendation unless it is hard to undo.
- Keep explanations short. Do not use em dashes anywhere, including code comments, UI text, and commit messages.
- File naming for any planning or note files you create: ISO date prefix and a descriptive title, for example "20261118 Page2 Kanban". Do not edit my Obsidian Kanban file.
- Swift style: Swift 5 language mode, SwiftData and Observation, no force unwraps in production code, small focused files under Page2/ grouped by Models, Services, Views, and Resources.
- Be honest about what you did not verify. If a build or test did not run, say so.

Start with Milestone 1.
