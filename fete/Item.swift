//
//  Item.swift
//  fete
//
//  Created by Raidel Almeida on 4/3/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var id: String
    var name: String
    var imageUrl: String?
    
    init(id: String, name: String, imageUrl: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.timestamp = timestamp
    }
}
