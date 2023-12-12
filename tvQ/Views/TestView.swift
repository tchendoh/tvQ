//
//  TestView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-14.
//

import SwiftUI

struct TestView: View {
    @State private var isClicked = false
    var body: some View {
        Rectangle()
            .frame(width: 200, height: 200)
            .scaleEffect(isClicked ? 1.05 : 1)
            .onTapGesture {
                withAnimation(.bouncy(duration: 0.1)) {
                    isClicked.toggle()
                } completion: {
                    withAnimation(.bouncy(duration: 0.3)) {
                        isClicked.toggle()
                    }
                }
            }
    }
}

#Preview {
    TestView()
}
