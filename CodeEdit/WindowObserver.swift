//
//  WindowObserver.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 14/01/2023.
//

import SwiftUI

struct WindowObserver<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
    }
}
