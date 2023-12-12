//
//  SettingsScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-23.
//

import SwiftUI


struct SettingsScreen: View {
    @Environment(ViewModel.self) private var vm: ViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager
    @AppStorage("colorScheme") var selectedColorScheme: String = "system"
    @Binding var navManager: NavManager

    @State private var showLoginSheet = false
    @State private var tvUser: TVUser?
    @State private var countrySelection: TVUser.Country = .unitedStates
    @State private var languageSelection: TVUser.Language = .english
    
    var body: some View {
        NavigationStack(path: $navManager.settingsStack) {
            VStack {
                if let _ = authManager.user?.uid {
                    List {
                        Text("\(authManager.user?.email ?? "Email placeholder")")
                            .bold()
                        NavigationLink(value: "AboutScreen") {
                            Text("About")
                        }
                        .navigationDestination(for: String.self) { _ in
                            AboutScreen()
                        }
                        

                        Picker(selection: $selectedColorScheme, label: Text("Color Scheme")) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .preferredColorScheme(getPreferredColorScheme())

                        Picker(selection: $countrySelection) {
                            ForEach(TVUser.Country.allCases, id: \.self) { country in
                                Text("\(country.englishName)").tag(country)
                            }
                        } label: {
                            Text("Country")
                        }

                        
                        Picker(selection: $languageSelection) {
                            ForEach(TVUser.Language.allCases, id: \.self) { language in
                                Text("\(language.englishName)").tag(language)
                            }
                        } label: {
                            Text("Language")
                        }
                        
                        // Show `Sign out` if user is not anonymous,
                        // otherwise show `Sign-in` to present LoginView() when tapped.
                        Button {
                            if authManager.authState != .signedIn {
                                showLoginSheet = true
                            } else {
                                signOut()
                            }
                        } label: {
                            Text(authManager.authState != .signedIn ? "Sign-in" :"Sign out")
                        }

                    }
                    
                }
            }
            
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginScreen()
        }
        .onChange(of: countrySelection, initial: false) { oldValue, newValue in
            Task {
                try await vm.updateUserCountry(country: newValue)
            }
        }
        .onChange(of: languageSelection, initial: false) { oldValue, newValue in
            Task {
                try await vm.updateUserLanguage(language: newValue)
            }
        }
        .task {
            Task {
                if let userId = authManager.user?.uid {
                    tvUser = try await vm.fetchUser(userId: userId)
                    if let userCountry = tvUser?.country {
                        countrySelection = userCountry
                    }
                    if let userLanguage = tvUser?.language {
                        languageSelection = userLanguage
                    }
                    
                }
            }
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await authManager.signOut()
            }
            catch {
                print("Error: \(error)")
            }
        }
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch selectedColorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

//#Preview {
//    SettingsScreen()
//        .environment(ViewModel(apiService: APIManager(), dataService: DataManager()))
//        .environment(AuthManager.shared)
//}
