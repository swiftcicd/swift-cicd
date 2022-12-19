import Foundation

public extension StringProtocol {
    var data: Data {
        Data(self.utf8)
    }
}

public extension Data {
    var string: String {
        String(decoding: self, as: UTF8.self)
    }
}
