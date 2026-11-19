//
//  LogChunks.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Splits a long message into pieces a log can keep whole, such as the unified log, which cuts
/// a message at about 1 KB. Pieces break between lines, so a journey box arrives as consecutive
/// groups of whole rows.
package enum LogChunks {
    /// The most bytes of UTF-8 a piece holds, safely under the unified log's limit.
    package static let maxBytes = 900

    /// `text` in pieces of at most `maxBytes` bytes each, broken between lines; a single line
    /// longer than that is broken between characters. A short text is one piece.
    package static func split(_ text: String, maxBytes: Int = maxBytes) -> [String] {
        guard text.utf8.count > maxBytes else {
            return [text]
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).flatMap { line in
            pieces(of: String(line), maxBytes: maxBytes)
        }
        return lines.reduce(into: [String]()) { chunks, line in
            guard let last = chunks.last, last.utf8.count + 1 + line.utf8.count <= maxBytes else {
                chunks.append(line)
                return
            }
            chunks[chunks.count - 1] = last + "\n" + line
        }
    }

    /// One line, in pieces of at most `maxBytes` bytes, broken between characters.
    private static func pieces(of line: String, maxBytes: Int) -> [String] {
        guard line.utf8.count > maxBytes else {
            return [line]
        }
        return line.reduce(into: [""]) { pieces, character in
            let size = String(character).utf8.count
            guard pieces[pieces.count - 1].utf8.count + size <= maxBytes else {
                pieces.append(String(character))
                return
            }
            pieces[pieces.count - 1].append(character)
        }
    }
}
