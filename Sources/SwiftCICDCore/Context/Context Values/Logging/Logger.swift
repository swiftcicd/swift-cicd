import Logging

private var _logger = Logger(label: "swift-cicd")

public extension ContextValues {
    var logger: Logger {
        get { _logger }
        nonmutating set { _logger = newValue }
    }
}
