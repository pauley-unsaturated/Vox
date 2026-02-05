//
//  Item.swift
//  Vox
//
//  Created by Mark Pauley on 5/16/25.
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
