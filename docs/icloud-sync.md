# iCloud sync plan (not yet implemented)

This documents what it would take to sync Page 2 data across Mac, iPad, and
iPhone automatically. It is deliberately not built yet. OPML import and export
cover manual syncing today without any of the requirements below.

## Why it is not built

Two hard requirements block it on the current setup:

1. **A paid Apple Developer account is required.** iCloud and CloudKit
   entitlements are not available with free provisioning (the 7 day profiles we
   use now). This needs the Apple Developer Program at 99 USD per year.
2. **CloudKit does not allow `@Attribute(.unique)`.** The models use unique
   constraints on `Source.slug`, `Article.link`, and `Story.id`. A CloudKit
   backed SwiftData store rejects these, so they must be removed and the
   deduplication they provide must be done in code.

## What the implementation would involve

### 1. Account and capability
- Join the Apple Developer Program.
- In the target, add the iCloud capability with CloudKit, and create a container,
  for example `iCloud.com.jayclark.page2`.
- Add entitlements: `com.apple.developer.icloud-services` (CloudKit),
  `com.apple.developer.icloud-container-identifiers`, and the
  `aps-environment` background push key for sync notifications.
- In `project.yml`, these go under the target entitlements for both platforms,
  not gated to macOS like the sandbox keys.

### 2. Model changes (required by CloudKit)
- Remove `@Attribute(.unique)` from `Source.slug`, `Article.link`, `Story.id`.
- Make every relationship optional (already true here) and give every stored
  property a default value or make it optional. Most already comply.
- Replace the uniqueness guarantee with explicit lookups before insert, which the
  seeder, the article upsert, and clustering already do by fetching first. The
  main risk is duplicate rows created on two devices at once, so add a
  reconciliation pass that merges records with the same slug or link.

### 3. Container configuration
- Switch the model container to a CloudKit database:
  ```swift
  .modelContainer(for: [Source.self, Article.self, Story.self],
                  isAutosaveEnabled: true)
  // with ModelConfiguration(cloudKitDatabase: .automatic)
  ```
- Test the schema in the CloudKit development environment, then push it to
  production before shipping, or first launch on a clean account will fail.

### 4. Things to decide
- Sync everything, or only sources and the enabled and deleted flags. Syncing
  articles and stories is heavier and they regenerate on refresh, so syncing only
  `Source` (the user owned data) may be the better scope. SwiftData syncs the
  whole store, so limiting scope means a second, non synced container for
  articles and stories.
- Conflict policy for the same outlet edited on two devices. Last writer wins is
  the default and is fine here.

## Estimate

Roughly a day: the model and dedup changes are the real work, plus CloudKit
schema testing. The account upgrade is the prerequisite. Ping me when you have
the paid account and I will wire it up.
