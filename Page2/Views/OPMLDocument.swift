import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// OPML is XML based. Declared dynamically so no Info.plist entry is needed.
    static let opml = UTType(filenameExtension: "opml", conformingTo: .xml) ?? .xml
}

/// A plain text file document used to export and import OPML.
struct OPMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.opml, .xml] }
    static var writableContentTypes: [UTType] { [.opml] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
