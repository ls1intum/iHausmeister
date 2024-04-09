//
//  TasksView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import SwiftUI

/// View showing all tasks grouped by weekly and daily tasks.
struct TasksView: View {
    @State private var tasksModel = TasksModel()
    
    var body: some View {
        List {
            Section("Weekly Tasks") {
                ForEach(tasksModel.weeklyTasks, id: \.self) { task in
                    TaskView(task: task)
                }
            }
            
            Section("Daily Tasks") {
                ForEach(tasksModel.dailyTasks, id: \.self) { task in
                    TaskView(task: task)
                }
            }
        }
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }
}

#Preview {
    TasksView()
}
