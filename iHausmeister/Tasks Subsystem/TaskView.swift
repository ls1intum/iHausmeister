//
//  TaskView.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import SwiftUI

/// View showing a single task with a toogle button next to it to mark it as completed.
struct TaskView: View {
    @Bindable var task: IHausmeisterTask
    
    var body: some View {
        Toggle(isOn: $task.done) {
            Text(task.name).foregroundStyle(task.done ? .secondary : .primary)
        }
    }
}

#Preview {
    TaskView(task: IHausmeisterTask(name: "Task 1", done: false))
}
