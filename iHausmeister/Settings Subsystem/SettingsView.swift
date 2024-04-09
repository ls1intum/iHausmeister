//
//  SettingsView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import SwiftUI

/// View showing input fields for the name, the username, and the password.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsViewModel: SettingsViewModel
    
    init(_ model: Model) {
        self._settingsViewModel = State(wrappedValue: SettingsViewModel(model: model))
    }
    
    var body: some View {
        Form {
            TextField(
                "Your Name",
                text: $settingsViewModel.name
            )
            
            Section(header: Text("TUM Credentials")) {
                TextField(
                    "Username",
                    text: $settingsViewModel.username
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()
                
                SecureField(
                    "Password",
                    text: $settingsViewModel.password
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()
            }
            Button {
                Task {
                    settingsViewModel.save()
                    dismiss()
                }
            } label: {
                Text("Save")
                    .bold()
            }
            
            AboutView()
        }
    }
}

#Preview {
    let model = Model()
    
    return SettingsView(model).environment(model)
}
