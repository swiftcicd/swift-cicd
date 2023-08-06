import SwiftCICD

@main
struct Demo: MainAction {
    @Value var simulatorBuild: Xcode.Build.Output?

    var body: some Action {
        Xcode.Build()
            .storeOutput(in: $simulatorBuild)

        if let build = simulatorBuild?.product {
            GitHub.UploadActionArtifact(build.url, named: build.name)
        }

        RequireValue($simulatorBuild, \.product) { build in
            GitHub.UploadActionArtifact(build.url, named: build.name)
        }

        WithOutput(\.latestXcodeBuildProduct?.product) { build in
            GitHub.UploadActionArtifact(build.url, named: build.name)
        }
    }
}

struct PrintHello: Action {
    var person: String
    var greeting: String

    init(to person: String, greeting: String = "Hello") {
        self.person = person
        self.greeting = greeting
    }

    func run() async throws {
        print("\(greeting), \(person)")
    }
}

struct Count: Action {
    var upperLimit: Int

    init(to upperLimit: Int) {
        self.upperLimit = upperLimit
    }

    func run() async throws {
        print("\((0...upperLimit).map { "\($0)" }.joined(separator: ", "))")
    }
}
