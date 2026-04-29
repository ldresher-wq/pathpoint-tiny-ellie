import Foundation

// MARK: - Model

struct ClassCodeRow {
    let vertical: String
    let classCode: String
    let classOfBusiness: String
    let linesOfBusiness: String
    let submissions12m: Int
    let autoQuoted12m: Int
    let bound12m: Int
    let autoQuoteRatePct: Double
    let bindRatePct: Double
    let appetiteNote: String
}

// MARK: - Archive

final class ClassCodeArchive {
    static let shared = ClassCodeArchive()

    private(set) var rows: [ClassCodeRow] = []
    private var isLoaded = false

    private init() {}

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let root = Bundle.main.resourceURL?.appendingPathComponent("StarterArchive", isDirectory: true) else { return }
        let csvURL = root.appendingPathComponent("class-codes.csv")
        guard let raw = try? String(contentsOf: csvURL, encoding: .utf8) else { return }

        var lines = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return }
        lines.removeFirst() // skip header

        rows = lines.compactMap { Self.parseRow($0) }
        SessionDebugLogger.log("class-code-archive", "loaded \(rows.count) class code rows")
    }

    // MARK: - Search

    func search(query: String, limit: Int = 10) -> [ClassCodeRow] {
        loadIfNeeded()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let tokens = queryTokens(from: query)
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var scored: [(row: ClassCodeRow, score: Int)] = rows.compactMap { row in
            let s = score(row: row, query: lower, tokens: tokens)
            return s > 0 ? (row, s) : nil
        }

        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.row.submissions12m > $1.row.submissions12m }
        return scored.prefix(limit).map(\.row)
    }

    // MARK: - Context formatting

    func promptContext(for rows: [ClassCodeRow]) -> String {
        guard !rows.isEmpty else { return "" }

        let header = "Pathpoint eligible class code data (\(rows.count) result\(rows.count == 1 ? "" : "s")):"
        let entries = rows.enumerated().map { idx, row in
            let autoQ = String(format: "%.1f%%", row.autoQuoteRatePct)
            let bind  = String(format: "%.1f%%", row.bindRatePct)
            return """
            \(idx + 1). [\(row.vertical)] Code \(row.classCode) — \(row.classOfBusiness)
               Lines: \(row.linesOfBusiness)
               Auto-quote rate: \(autoQ) | Bind rate: \(bind) | 12-mo submissions: \(row.submissions12m)
               Appetite: \(row.appetiteNote)
            """
        }
        return ([header] + entries).joined(separator: "\n")
    }

    // MARK: - Scoring

    private func score(row: ClassCodeRow, query: String, tokens: [String]) -> Int {
        let codeNorm    = row.classCode.lowercased()
        let cobNorm     = row.classOfBusiness.lowercased()
        let vertNorm    = row.vertical.lowercased()
        let noteNorm    = row.appetiteNote.lowercased()
        let linesNorm   = row.linesOfBusiness.lowercased()

        var s = 0

        // Exact class code hit (query IS the code or query CONTAINS the code as a word)
        if query == codeNorm { s += 120 }
        else if query.contains(codeNorm) { s += 100 }

        // Exact class-of-business match
        if cobNorm == query { s += 90 }
        else if cobNorm.contains(query) { s += 50 }

        // Token-level scoring
        for token in tokens {
            if codeNorm.contains(token)  { s += 80 }
            if cobNorm.contains(token)   { s += 25 }
            if vertNorm.contains(token)  { s += 10 }
            if noteNorm.contains(token)  { s += 5  }
            if linesNorm.contains(token) { s += 4  }
        }

        return s
    }

    private func queryTokens(from query: String) -> [String] {
        query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    // MARK: - CSV parsing

    /// Parses a single CSV line with proper quoted-field support.
    private static func parseRow(_ line: String) -> ClassCodeRow? {
        let fields = csvFields(from: line)
        guard fields.count >= 10 else { return nil }

        let vertical        = fields[0].trimmingCharacters(in: .whitespaces)
        let classCode       = fields[1].trimmingCharacters(in: .whitespaces)
        let classOfBusiness = fields[2].trimmingCharacters(in: .whitespaces)
        let lines           = fields[3].trimmingCharacters(in: .whitespaces)
        let subs12m         = Int(fields[4].trimmingCharacters(in: .whitespaces)) ?? 0
        let autoQ12m        = Int(fields[5].trimmingCharacters(in: .whitespaces)) ?? 0
        let bound12m        = Int(fields[6].trimmingCharacters(in: .whitespaces)) ?? 0
        let autoQRate       = Double(fields[7].trimmingCharacters(in: .whitespaces)) ?? 0
        let bindRate        = Double(fields[8].trimmingCharacters(in: .whitespaces)) ?? 0
        let note            = fields[9].trimmingCharacters(in: .whitespaces)

        guard !classCode.isEmpty, !classOfBusiness.isEmpty else { return nil }

        return ClassCodeRow(
            vertical: vertical,
            classCode: classCode,
            classOfBusiness: classOfBusiness,
            linesOfBusiness: lines,
            submissions12m: subs12m,
            autoQuoted12m: autoQ12m,
            bound12m: bound12m,
            autoQuoteRatePct: autoQRate,
            bindRatePct: bindRate,
            appetiteNote: note
        )
    }

    /// RFC-4180-compliant CSV field splitter.
    private static func csvFields(from line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var idx = line.startIndex

        while idx < line.endIndex {
            let ch = line[idx]
            if inQuotes {
                if ch == "\"" {
                    let next = line.index(after: idx)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        idx = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            idx = line.index(after: idx)
        }
        fields.append(current)
        return fields
    }
}
