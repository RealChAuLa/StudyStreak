//
//  Item.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
