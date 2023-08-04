import SwiftCICD

@main
struct Demo: MainAction {
//    func run() async throws {
//        try await xcode.build()
//    }

    var body: some Action {
        Group("Demo Group") {
            PrintHello(to: "World")

            for i in 0...5 {
                Count(to: i)
            }
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
