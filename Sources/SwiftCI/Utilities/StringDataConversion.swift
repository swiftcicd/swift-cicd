import Foundation

extension StringProtocol {
    var data: Data {
        Data(self.utf8)
    }
}

extension Data {
    var string: String {
        String(decoding: self, as: UTF8.self)
    }
}
