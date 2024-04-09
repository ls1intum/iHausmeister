//
//  ContentView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import SwiftUI

/// Main view showing the toolbar, the ``SettingsView``,  ``CalendarView``, and ``StatusView``.
struct ContentView: View {
    @State private var settingsSheetOpen = false
    @State var model = Model()
    
    var body: some View {
        TabView {
            NavigationStack {
                VStack {
                    if model.username == nil {
                        Text("Please start by logging in!")
                    } else {
                        CalendarView(model)
                    }
                }
                .padding(.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle(model.userGreeting)
                .toolbar {
                     ToolbarItem(placement: .primaryAction) {
                         Button(action: {
                             settingsSheetOpen.toggle()
                         }, label: {
                             Image(systemName: "gear")
                         })
                     }
                }
                .sheet(
                    isPresented: $settingsSheetOpen,
                    content: {
                        SettingsView(model)
                    }
                )
            }
            .environment(model)
            .tabItem {
                Label("Hausmeister", systemImage: "note.text")
            }
            
            LinkView().tabItem {
                Label("Links", systemImage: "link")
            }
        }
    }
}

#Preview {
    ContentView()
}
