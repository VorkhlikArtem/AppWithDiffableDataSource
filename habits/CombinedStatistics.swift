//
//  CombinedStatistics.swift
//  habits
//
//  Created by Артём on 01.05.2022.
//

import Foundation
struct CombinedStatistics{
    let userStatictics: [UserStatistics]
    let habitStatistics: [HabitStatistics]
}
extension CombinedStatistics: Codable{}
