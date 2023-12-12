//
//  EpisodeNumberView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-02.
//

import SwiftUI

struct EpisodeNumberView: View {
    var episodeNumber: Int
    var seasonNumber: Int
    var body: some View {
        Text("S\(String(format: "%02d", seasonNumber))E\(String(format: "%02d", episodeNumber))")
            .font(.system(size: 14))
            .fontWeight(.bold)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
    }
}

//#Preview {
//    EpisodeNumberView()
//}
