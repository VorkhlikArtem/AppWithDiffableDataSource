//
//  HabitStatistics.swift
//  habits
//
//  Created by Артём on 26.04.2022.
//

import Foundation
struct HabitStatistics{
    let habit: Habit
    let userCount: [UserCount]
}
extension HabitStatistics: Codable{}
