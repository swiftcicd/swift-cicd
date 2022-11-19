import Foundation

public struct Secret {
    let source: Source
    var encoding: Encoding?

    public init(source: Source, encoding: Encoding?) {
        self.source = source
        self.encoding = encoding
    }

    public enum Source {
        case environment(String)
    }

    public enum Encoding {
        case base64
    }
}

public protocol LoadedSecret {
    init(secretString: String)
    init(secretData: Data)
}

extension String: LoadedSecret {
    public init(secretString: String) {
        self = secretString
    }

    public init(secretData: Data) {
        self.init(decoding: secretData, as: UTF8.self)
    }
}

extension Data: LoadedSecret {
    public init(secretString: String) {
        self.init(secretString.utf8)
    }

    public init(secretData: Data) {
        self = secretData
    }
}

public extension StepRunner {
    func loadSecret<Loaded: LoadedSecret>(_ secret: Secret) throws -> Loaded {
        switch secret.source {
        case .environment(let key):
            let value = try context.environment.require(key)
            switch secret.encoding {
            case .none:
                return Loaded(secretString: value)

            case .some(.base64):
                guard let data = Data(base64Encoded: value, options: .ignoreUnknownCharacters) else {
                    throw StepError("Failed to base64-decode secret")
                }

                return Loaded(secretData: data)
            }
        }
    }
}
