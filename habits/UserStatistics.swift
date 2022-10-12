//
//  UserStatics.swift
//  habits
//
//  Created by Артём on 29.04.2022.
//

import Foundation
struct UserStatistics {
    let user: User
    let habitCount: [HabitCount]
}

extension UserStatistics: Codable {}
