import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ResponderExpert: Equatable {
    let name: String
    let avatarPath: String
    let archiveContext: String
    let responseScript: String
}

struct SessionAttachment: Equatable {
    enum Kind: Equatable {
        case image
        case document
    }

    let url: URL
    let kind: Kind
    let detail: String

    var displayName: String { url.lastPathComponent }
    var fileExtensionLabel: String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? "FILE" : ext.uppercased()
    }

    static let supportedTextExtensions = Set([
        "md", "markdown", "txt", "rtf", "json", "csv", "tsv", "log",
        "yaml", "yml", "xml", "html", "htm",
        "js", "jsx", "ts", "tsx", "swift", "py", "rb", "go", "rs", "java", "kt",
        "c", "cc", "cpp", "h", "hpp", "m", "mm", "css", "scss", "sql", "sh"
    ])

    static var supportedContentTypes: [UTType] {
        [
            .image,
            .pdf,
            .plainText,
            .utf8PlainText,
            .rtf,
            .commaSeparatedText,
            .json,
            .xml,
            .html,
            .sourceCode
        ]
    }

    static func from(url: URL) -> SessionAttachment? {
        let lowercasedExtension = url.pathExtension.lowercased()

        if let type = UTType(filenameExtension: lowercasedExtension) {
            if type.conforms(to: .image) {
                return SessionAttachment(url: url, kind: .image, detail: "Image")
            }
            if type.conforms(to: .pdf) {
                return SessionAttachment(url: url, kind: .document, detail: "PDF")
            }
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) {
                return SessionAttachment(url: url, kind: .document, detail: displayDetail(for: lowercasedExtension, type: type))
            }
        }

        if supportedTextExtensions.contains(lowercasedExtension) {
            return SessionAttachment(url: url, kind: .document, detail: displayDetail(for: lowercasedExtension, type: nil))
        }

        return nil
    }

    static func displayDetail(for lowercasedExtension: String, type: UTType?) -> String {
        switch lowercasedExtension {
        case "csv":
            return "CSV"
        case "tsv":
            return "TSV"
        case "json":
            return "JSON"
        case "md", "markdown":
            return "Markdown"
        case "txt", "":
            return "Text"
        case "pdf":
            return "PDF"
        case "rtf":
            return "RTF"
        case "yaml", "yml":
            return "YAML"
        case "xml":
            return "XML"
        default:
            if type?.conforms(to: .sourceCode) == true {
                return "Code"
            }
            if type?.conforms(to: .image) == true {
                return "Image"
            }
            return lowercasedExtension.isEmpty ? "Document" : lowercasedExtension.uppercased()
        }
    }
}

struct ConversationState {
    var previousResponseID: String?
    var history: [ClaudeSession.Message] = []
    var expertSuggestionEntries: [ExpertSuggestionEntry] = []
}

struct ExpertSuggestionEntry: Equatable {
    let id: UUID
    let anchorHistoryCount: Int
    let experts: [ResponderExpert]
    var pickedExpert: ResponderExpert?
    var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        anchorHistoryCount: Int,
        experts: [ResponderExpert],
        pickedExpert: ResponderExpert? = nil,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.anchorHistoryCount = anchorHistoryCount
        self.experts = experts
        self.pickedExpert = pickedExpert
        self.isCollapsed = isCollapsed
    }
}

struct SearchEnvelope: Decodable {
    let results: [SearchResult]
}

struct SearchResult: Decodable {
    let title: String
    let filename: String
    let type: String
    let date: String
    let snippet: String?
    let snippets: [Snippet]?
}

struct Snippet: Decodable {
    let text: String
}

extension ClaudeSession {
    struct Message: Equatable {
        enum Role { case user, assistant, error, toolUse, toolResult }
        let role: Role
        let text: String
    }
}
