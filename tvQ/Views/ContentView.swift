//
//  ContentView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-12.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager: AuthManager
    @Environment(ViewModel.self) private var vm: ViewModel

    var body: some View {
        if authManager.authState == .signedOut {
            LoginScreen()
        } else {
            TabScreen()
                .task {
                    if let userId = authManager.user?.uid {
                        Task {
                            try await vm.initializeUser(userId: userId)
                        }                        
                    }
                    
                }
        }
    }
}

#Preview {
    ContentView()
}
