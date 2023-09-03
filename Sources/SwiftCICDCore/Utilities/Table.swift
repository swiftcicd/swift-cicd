import Foundation

struct Table {
    let headers: [String?]
    let rows: [[String?]]

    init(headers: [String?], rows: [[String?]]) {
        if let invalidRow = rows.firstIndex(where: { $0.count != headers.count }) {
            preconditionFailure(
                "Invalid number of columns (\(rows[invalidRow].count)) in row \(invalidRow). Expected \(headers.count)."
            )
        }

        self.headers = headers
        self.rows = rows
    }

    func textualDescription(padding: Int = 2) -> String {
        var lines = [String]()
        var columnWidths = headers.map { $0?.count ?? 0 }
        for rowIndex in rows.indices {
            for columnIndex in headers.indices {
                if let value = rows[rowIndex][columnIndex], value.count > columnWidths[columnIndex] {
                    columnWidths[columnIndex] = value.count
                }
            }
        }

        // The amount of padding to add around each cell
        columnWidths = columnWidths.map { $0 + padding }

        func addLine(separator: String, cell: ((_ columnIndex: Int) -> String?)? = nil) {
            var line = separator
            if let cell {
                line += headers.indices.map { (cell($0) ?? " ").padded(to: columnWidths[$0]) }.joined(separator: separator)
            } else {
                line += columnWidths.map { separator.repeated($0) }.joined(separator: separator)
            }
            line += separator
            lines.append(line)
        }

        addLine(separator: "=")
        addLine(separator: "|") { headers[$0] }
        addLine(separator: "=")
        for row in rows {
            addLine(separator: "|") { row[$0] }
        }
        addLine(separator: "-")
        return lines.joined(separator: "\n")
    }
}

private extension String {
    init(repeating sequence: String, count: Int) {
        self = Array(repeating: sequence, count: count).joined()
    }

    func repeated(_ count: Int) -> String {
        StringLiteralType(repeating: self, count: count)
    }

    func padded(to length: Int, with padding: String = " ") -> String {
        return (padding + (self.isEmpty ? " " : self)).padding(toLength: length, withPad: padding, startingAt: 0)
    }
}
