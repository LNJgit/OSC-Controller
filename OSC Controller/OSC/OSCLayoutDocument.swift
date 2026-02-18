import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Custom file type for a single exported layout.
    /// NOTE: Without an Info.plist type declaration, iOS may not reliably associate
    /// a filename extension with a custom UTI. We still conform to JSON so the picker
    /// can treat it like a JSON document.
    static let oscLayout = UTType(exportedAs: "com.yourcompany.osccontroller.layout", conformingTo: .json)
}

struct OSCLayoutDocument: FileDocument {
    // Read either our custom type or plain JSON.
    static var readableContentTypes: [UTType] { [.oscLayout, .json] }

    // Write as plain JSON for maximum compatibility with iOS/iCloud/Files.
    // (fileExporter requires the contentType to be included here.)
    static var writableContentTypes: [UTType] { [.json] }

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
