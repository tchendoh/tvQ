//
//  AboutScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-06.
//

import SwiftUI

struct AboutScreen: View {
    var body: some View {
        ScrollView {
            VStack (alignment: .leading) {
                HStack (spacing: 0) {
                    Spacer()
                    Image("tvQLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(0.2)
                        .padding(10)
                    Image("tvQLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(0.6)
                        .padding(10)
                    Image("tvQLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(10)
                    Spacer()
                }
                
                Text("tvQ is your exclusive hub for the finest in TV series. No movies, no reality shows. We're the zen garden of series entertainment.")
                    .font(.subheadline)
                    .opacity(0.9)
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                Text("Credits & thanks")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(.bottom, 2)
                Text("A massive shoutout to The Movie Database (TMDB) (http://themoviedb.org) and JustWatch (http://justwatch.com), our behind-the-scenes heroes, for graciously providing the data backstage access to make tvQ shine. Of course, IMDb updates faster than TMDB, but they come with a price tag in the six figures so... We opted for budget-friendly and user-friendly – that's tvQ for you!")
                Text("Future Development")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                Text("Hold onto your remote because tvQ is just getting started. We're cooking up new sections dedicated to trending series, driven by the community's whims and fancies. Your feedback is our secret sauce – so, bring it on!")
                Text("Me")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                Text("I'm Eric Chandonnet, your friendly neighborhood iOS developer with a knack for creating tools that are as useful... or just fun. This app, lovingly known as tvQ, is my brainchild. Join me on this journey and let's turn tvQ into the best binge-watching buddy you never knew you needed.")
            }
            .padding()
        }
    }
}

#Preview {
    AboutScreen()
}
