import Foundation

/// Nil-coalesces between the `rhs` and the `async` throwing `lhs`.
///
/// Autoclosures do not support async/await and so operators like the nil-coalescing operator (??)
/// cannot have an async expression on their right hand side.
///
/// - Parameters:
///   - lhs: The value to return if non-nil.
///   - rhs: The value to return if `rhs` is nil.
/// - Throws: Any errors thrown when `rhs` is evaluated.
/// - Returns: Either `rhs` or `lhs` or `nil` if neither is non-nil.
public func nilCoalesce<T>(_ lhs: T?, _ rhs: () async throws -> T?) async throws -> T? {
    if let lhs {
        return lhs
    } else {
        return try await rhs()
    }
}

/// Nil-coalesces between the `rhs` and the `async` throwing `lhs`.
///
/// Autoclosures do not support async/await and so operators like the nil-coalescing operator (??)
/// cannot have an async expression on their right hand side.
///
/// - Parameters:
///   - lhs: The value to return if non-nil.
///   - rhs: The value to return if `rhs` is nil.
/// - Throws: Any errors thrown when `rhs` is evaluated.
/// - Returns: Either `rhs` or `lhs`, whichever is non-nil.
public func nilCoalesce<T>(_ lhs: T?, _ rhs: () async throws -> T) async throws -> T {
    if let lhs {
        return lhs
    } else {
        return try await rhs()
    }
}
