import Foundation

public extension ByteString {
    var data: Data {
        Data(_bytes)
    }
}
