import SwiftCICD

@main
struct Demo: MainAction {
    @Value var simulatorBuild: Xcode.Build.Output?

    var body: some Action {
        Recover {
            Fail()
        } catch: { error in
            PrintHello(to: "Recovery")
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

struct Fail: Action {
    func run() async throws -> () {
        throw ActionError("forced failure")
    }
}
