//
//  TasksModel.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import Foundation
import os

@available(iOS 17.0, *)
/// Model containing logic for displaying tasks and when to reset the todo status.
@Observable public class TasksModel {
    private let logger = Logger()
    var weeklyTasks: [IHausmeisterTask]
    var dailyTasks: [IHausmeisterTask]
    
    var timer = Timer()
    var lastTimerCheck = Date()
    
    init() {
        weeklyTasks = []
        dailyTasks = []
        
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] _ in
            self?.resetToDoStatus()
        })
        
        weeklyTasks = [
            IHausmeisterTask(name: "Check Macs in Aquarium", done: false),
            IHausmeisterTask(name: "Clean up admin office", done: false),
            IHausmeisterTask(name: "Create agenda for next meeting", done: false)
        ]
        dailyTasks = [
            IHausmeisterTask(name: "Check for new tickets", done: false),
            IHausmeisterTask(name: "Check for new messages in Slack", done: false),
            IHausmeisterTask(name: "Check monitoring", done: false)
        ]
    }
    
    
    /// Resetting the todo status if necessary.
    func resetToDoStatus() {
        logger.trace("Check whether resetting the todo status is necessary")
        if !Calendar.current.isDate(lastTimerCheck, equalTo: Date(), toGranularity: .day) {
            logger.trace("Resetting daily tasks")
            for task in dailyTasks {
                task.done = false
            }
        }
        
        if !Calendar.current.isDate(lastTimerCheck, equalTo: Date(), toGranularity: .weekOfYear) {
            logger.trace("Resetting weekly tasks")
            for task in weeklyTasks {
                task.done = false
            }
        }
        
        lastTimerCheck = Date()
    }
}

@available(iOS 17.0, *)
/// Data type for the tasks of the current Hausmeister.
@Observable public class IHausmeisterTask: Hashable {
    public static func == (lhs: IHausmeisterTask, rhs: IHausmeisterTask) -> Bool {
        return lhs.done == rhs.done && lhs.name == rhs.name
    }
    
    var name: String
    var done: Bool
    
    init(name: String, done: Bool) {
        self.name = name
        self.done = done
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
