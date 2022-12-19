
public extension AbsolutePath {
    static func / (lhs: Self, rhs: String) -> AbsolutePath {
        lhs.appending(component: rhs)
    }
}
