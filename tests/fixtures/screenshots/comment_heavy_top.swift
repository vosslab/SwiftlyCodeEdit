// Comment-heavy fixture for the WP-G2 glass backdrop-differential capture.
// The top rows of this file are packed with commented lines so the syntax
// highlighter's comment color (green) dominates the rows directly under the
// toolbar edge, giving the chrome a strong colored backdrop to sample.
// Padding comment line five.
// Padding comment line six.
// Padding comment line seven.

import Foundation

struct CommentHeavyFixture {
    let value: Int = 7

    func describe() -> String {
        return "comment-heavy fixture"
    }
}

let fixture = CommentHeavyFixture()
print(fixture.describe())
