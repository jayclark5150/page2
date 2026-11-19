import XCTest
import SwiftData
@testable import Page2

final class SourceSeederTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Source.self, Article.self, Story.self,
                                           configurations: config)
        return ModelContext(container)
    }

    @MainActor
    func testSeedInsertsThenIsIdempotent() throws {
        let context = try makeContext()
        let seeder = SourceSeeder()

        let first = try seeder.seed(into: context)
        XCTAssertGreaterThan(first.inserted, 0)

        let second = try seeder.seed(into: context)
        XCTAssertEqual(second.inserted, 0, "Re-seeding should insert nothing new")
    }

    @MainActor
    func testDeletedSeededSourceIsNotResurrected() throws {
        let context = try makeContext()
        let seeder = SourceSeeder()
        try seeder.seed(into: context)

        let victim = try XCTUnwrap(try context.fetch(FetchDescriptor<Source>()).first)
        let slug = victim.slug
        victim.isDeleted = true
        try context.save()

        try seeder.seed(into: context)

        let after = try context.fetch(
            FetchDescriptor<Source>(predicate: #Predicate { $0.slug == slug })
        ).first
        XCTAssertEqual(after?.isDeleted, true, "A removed outlet stays removed after re-seeding")
    }

    @MainActor
    func testUserEditedBiasSurvivesReseed() throws {
        let context = try makeContext()
        let seeder = SourceSeeder()
        try seeder.seed(into: context)

        // Edit a seeded outlet's bias and mark it user edited.
        let edited = try XCTUnwrap(try context.fetch(FetchDescriptor<Source>()).first)
        let slug = edited.slug
        let newBias: Bias = edited.bias == .left ? .right : .left
        edited.bias = newBias
        edited.isUserEdited = true
        try context.save()

        try seeder.seed(into: context)

        let after = try context.fetch(
            FetchDescriptor<Source>(predicate: #Predicate { $0.slug == slug })
        ).first
        XCTAssertEqual(after?.bias, newBias, "A user edited bias is not overwritten by the seeder")
    }

    @MainActor
    func testUserAddedSourceIsUntouchedBySeeder() throws {
        let context = try makeContext()
        let user = Source(slug: "my-blog", name: "My Blog",
                          feedURLString: "https://example.com/feed",
                          bias: .center, isUserAdded: true)
        context.insert(user)
        try context.save()

        try SourceSeeder().seed(into: context)

        let found = try context.fetch(
            FetchDescriptor<Source>(predicate: #Predicate { $0.slug == "my-blog" })
        ).first
        XCTAssertEqual(found?.name, "My Blog")
        XCTAssertEqual(found?.isUserAdded, true)
    }
}
