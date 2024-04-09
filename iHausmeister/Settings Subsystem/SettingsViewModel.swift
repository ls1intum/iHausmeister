//
//  SettingsViewModel.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import Foundation
import os
import SwiftUI

/// View Model to process the information entered in ``SettingsView``.
@Observable class SettingsViewModel {
    private let logger = Logger()
    var name = ""
    var username = ""
    var password = ""
    
    private weak var model: Model?

    init(model: Model) {
        self.model = model

        guard let name = model.name, let username = model.username, let password = model.password else {
            return
        }
        self.name = name
        self.username = username
        self.password = password
    }
    
    /// Saves the user given input to ``Model``.
    func save() {
        logger.trace("Saving name '\(self.password)', username '\(self.username)', and password '***'")
        guard let model = model else {
            return
        }
        model.name = self.name
        model.username = self.username
        model.password = self.password
    }
}
