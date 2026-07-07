// Syntax smoke sample

import Foundation

struct SyntaxSmokeSample {
    let count: Int = 42
    let message: String = "hello, world"

    func compute(value: Double) -> Double {
        let result = value * 3.14 + Double(count)
        return result
    }
}

let sample = SyntaxSmokeSample()
print(sample.compute(value: 2.0))
