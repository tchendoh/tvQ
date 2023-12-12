//
//  ProvidersView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-03.
//

import SwiftUI

struct ProvidersView: View {
    var userCountry: TVUser.Country
    var providers: FullSingleTVResponse.WatchProvider.Result
    
    var body: some View {
        HStack {
            VStack (alignment: .leading) {
                Text("Where to stream in \(userCountry.englishName)")
                    .font(.title3)
                
                HStack (spacing: 10) {
                    if let countryProviders = getCountryProviders() {
                        if let flatrateProviders = countryProviders.flatrate {
                            HStack {
                                ForEach(flatrateProviders) { provider in
                                    ProviderView(provider: provider)
                                }
                            }
                        }
                        
                    }
                }
            }
            Spacer()
        }
    }

    private func getCountryProviders() -> FullSingleTVResponse.WatchProvider.Result.CountryResult? {
        switch userCountry {
        case .canada:
            if let canadianProviders = providers.CA {
                return canadianProviders
            }
        case .unitedStates:
            if let americanProviders = providers.US {
                return americanProviders
            }
        }
        return nil
    }
}

//#Preview {
//    ProvidersView()
//}
