//
//  UserCount.swift
//  habits
//
//  Created by Артём on 26.04.2022.
//

import Foundation
struct UserCount{
    let user: User
    let count: Int
}
extension UserCount: Codable {}
extension UserCount: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
    }
    static func == (lhs: UserCount, rhs: UserCount) -> Bool {
        return lhs.user == rhs.user
    }
}

