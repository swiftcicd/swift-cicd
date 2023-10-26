import Foundation

struct TransformedSecret: Secret {
    let base: Secret
    let transform: (Data) async throws -> Data

    func get() async throws -> Data {
        let baseData = try await base.get()
        let transformed = try await transform(baseData)
        return transformed
    }
}

public extension Secret {
    func transform(_ transformation: @escaping (Data) async throws -> Data) -> some Secret {
        TransformedSecret(base: self, transform: transformation)
    }

    func base64Decoded() -> some Secret {
        self.transform {
            guard let data = Data(base64Encoded: $0, options: .ignoreUnknownCharacters) else {
                throw ActionError("Failed to base64-decode secret")
            }

            return data
        }
    }

    func decoding<T: Decodable>(as type: T.Type, decoder: JSONDecoder = JSONDecoder(), map: @escaping (T) -> Data) -> some Secret {
        self.transform {
            let decoded = try decoder.decode(T.self, from: $0)
            return map(decoded)
        }
    }
}
