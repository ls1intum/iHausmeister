//
//  CalendarView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import SwiftUI

/// View displaying information about the Hausmeister and shows if necessary ``TaskView``.
struct CalendarView: View {
    @State private var calendarViewModel: CalendarViewModel
    
    init(_ model: Model) {
        self._calendarViewModel = State(wrappedValue: CalendarViewModel(model: model))
    }
    
    var body: some View {
        if calendarViewModel.errorOnNetworkCallOccured {
            Text("Error fetching information, please check your login credentials.")
        } else if !calendarViewModel.dataFetched() {
            Text("Loading data ...")
        } else {
            Text(calendarViewModel.getWeeksTillNextHausmeisterAsSentence())
            if calendarViewModel.isUserCurrentHausmeister() {
                TasksView()
            }
        }
    }
}

#Preview {
    let model = Model()
    
    return CalendarView(model).environment(model)
}
