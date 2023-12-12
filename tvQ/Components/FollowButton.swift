//
//  FollowButton.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-09.
//

import SwiftUI

struct FollowButton: View {
    @Environment(ViewModel.self) private var vm: ViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager

    var tvItem: TVUser.TVItem
    @State private var isFollowed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            Image(systemName: isFollowed ? "checkmark.circle" : "plus.viewfinder")
                .font(.system(size: 20))
                .fontWeight(.bold)
                .symbolRenderingMode(.palette)
                .symbolEffect(.bounce, value: isFollowed)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isFollowed ? .green : .pink, isFollowed ? .green : .pink)
                .onChange(of: isFollowed, initial: false) { oldValue, newValue in
                    Task {
                        if newValue == true {
                            try await vm.follow(tvItem: tvItem)
                        } else {
                            try await vm.unfollow(tvId: tvItem.tvId)
                        }
                    }
                }
                .task {
                    Task {
                        isFollowed = try await vm.isFollowed(tvId: tvItem.tvId)
                    }
                    
                }
            }
        .frame(width: 30, height: 30, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            withAnimation(.spring) {
                isFollowed.toggle()
            }
            
        }
    }

}

//#Preview {
//    ZStack {
//        Color.black
//        FollowButton(tvItem: )
//    }
//}
