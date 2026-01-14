//
//  ChangeRequest.swift
//  Buff Stuff
//

import Foundation

struct ChangeRequest: Identifiable, Codable {
    var id: UUID = UUID()
    var content: String
    var createdAt: Date = Date()
}
