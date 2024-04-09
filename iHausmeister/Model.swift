//
//  Model.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import Foundation
import SwiftUI

@available(iOS 17.0, *)
/// Model containing main configuration for name, username, and password.
@Observable public class Model {
    public var name: String?
    public var username: String?
    public var password: String?
    
    /// Returns a personalised user greeting based on the name.
    public var userGreeting: String {
        if let name = name {
            return "Hi \(name) 👋"
        } else {
            return "Hi 👋"
        }
    }
}
