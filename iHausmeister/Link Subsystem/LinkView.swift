//
//  LinkView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 06.04.24.
//

import SwiftUI

/// View showing the ``LinkViewModel/links``.
struct LinkView: View {
    @State private var linkViewModel = LinkViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(linkViewModel.links, id: \.name) { link in
                        if let url = URL(string: link.url) {
                            Link(link.name, destination: url)
                        }
                    }
                }
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .padding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Links")
        }
    }
}

#Preview {
    LinkView()
}
