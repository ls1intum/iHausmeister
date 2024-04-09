//
//  Event.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 05.04.24.
//

import Foundation

/// Stores relevant information related to a iCal event.
struct Event {
    let attendee: String
    let startDate: Date
    let endDate: Date
}
