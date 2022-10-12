//
//  LoggedHabit.swift
//  habits
//
//  Created by Артём on 30.04.2022.
//

import Foundation
struct LoggedHabit{
    let userId: String
    let habitName: String
    let timestamp: Date
}
extension LoggedHabit: Codable {}
