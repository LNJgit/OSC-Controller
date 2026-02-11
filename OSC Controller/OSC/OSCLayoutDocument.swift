import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Custom file type for a single exported layout.
    static let oscLayout = UTType(exportedAs: "com.yourcompany.osccontroller.layout")
}

struct OSCLayoutDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.oscLayout, .json] }
    static var writableContentTypes: [UTType] { [.oscLayout] }

    var layout: OSCLayout

    init(layout: OSCLayout) {
        self.layout = layout
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.layout = try JSONDecoder().decode(OSCLayout.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(layout)
        return FileWrapper(regularFileWithContents: data)
    }
}
