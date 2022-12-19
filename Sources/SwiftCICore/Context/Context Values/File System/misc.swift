// https://github.com/apple/swift-tools-support-core/blob/main/Sources/TSCBasic/misc.swift

/*
 This source file is part of the Swift.org open source project
 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension AbsolutePath {
    /// File URL created from the normalized string representation of the path.
    public var asURL: Foundation.URL {
         return URL(fileURLWithPath: pathString)
    }
}
