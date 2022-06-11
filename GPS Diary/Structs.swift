//
//  Structs.swift
//  GPS Diary
//
//  Created by Robert Spang on 21.10.21.
//

import Foundation


struct StopDataPoint: Codable {
    
    var longitude: Double
    var latitude: Double
    var accuracy: Double
    var start_time: Date?
    var end_time: Date?
    var description: String?
    var pre_stop_modality: String?
    var stop_type: String?
    
}
