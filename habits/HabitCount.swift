//
//  HabitCount.swift
//  habits
//
//  Created by Артём on 29.04.2022.
//

import Foundation
struct HabitCount {
    let habit: Habit
    let count: Int
}
extension HabitCount: Codable {}
extension HabitCount : Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(habit)
    }
    static func == (lhs: HabitCount, rhs: HabitCount) -> Bool {
        return lhs.habit == rhs.habit
    }
}
extension HabitCount: Comparable {
    static func < (lhs: HabitCount, rhs: HabitCount) -> Bool {
        return lhs.habit < rhs.habit
    }
    
    
}
