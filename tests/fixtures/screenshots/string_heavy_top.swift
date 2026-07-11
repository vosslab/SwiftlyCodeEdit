let line1 = "String-heavy fixture for the WP-G2 glass backdrop-differential capture."
let line2 = "The top rows of this file are packed with string literals so the syntax"
let line3 = "highlighter's string color (red) dominates the rows directly under the"
let line4 = "toolbar edge, giving the chrome a strong colored backdrop to sample."
let line5 = "Padding string line five."
let line6 = "Padding string line six."
let line7 = "Padding string line seven."

import Foundation

struct StringHeavyFixture {
    let value: Int = 9

    func describe() -> String {
        return "string-heavy fixture"
    }
}

let fixture = StringHeavyFixture()
print(fixture.describe())
