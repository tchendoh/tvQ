//
//  tvQApp.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-12.
//

import SwiftUI
import Firebase
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct tvQApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var authManager: AuthManager
    

    init() {
        // Use Firebase library to configure APIs
        FirebaseApp.configure()
        
        let authManager = AuthManager.shared
        _authManager = State(wrappedValue: authManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(ViewModel(apiService: APIManager(), dataService: DataManager()))
        }
    
    }
}
