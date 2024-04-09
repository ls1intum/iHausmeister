//
//  AboutView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 05.04.24.
//

import SwiftUI


/// View showing the information about the app.. Uses a custom font.
struct AboutView: View {
    var body: some View {
        Section {
            (
                Text("Build with ") +
                Text(Image(systemName: "heart.fill")).foregroundColor(.red) +
                Text(" and ") +
                Text(Image(systemName: "swift")) +
                Text(" in the iPraktikum Intro Course.")
            ).font(Font.custom("CutiveMono-Regular", size: 16))
            .multilineTextAlignment(.center)
            .listRowBackground(EmptyView())
        }
    }
}

#Preview {
    AboutView()
}
