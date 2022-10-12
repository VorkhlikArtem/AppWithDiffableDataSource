//
//  User.swift
//  habits
//
//  Created by Артём on 26.04.2022.
//

import Foundation

struct User{
    let id: String
    let name: String
    let color: Color?
    let bio: String?
}
extension User: Codable{}

extension User: Hashable, Comparable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func < (lhs: User, rhs: User) -> Bool {
        return lhs.name < rhs.name
    }
    
    
}
