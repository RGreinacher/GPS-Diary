//
//  StopTableViewController.swift
//  GPS Diary
//
//  Created by Robert Spang on 21.10.21.
//

import UIKit



class StopTableViewCell: UITableViewCell {

    @IBOutlet var addressLabel: UILabel!
    @IBOutlet var startLabel: UILabel!
    @IBOutlet var endLabel: UILabel!


    
    func setupLabels(stopData: StopDataPoint) {
        if let description = stopData.description {
            addressLabel.text = description
        } else {
            let lat = String(format: "%.5f", stopData.latitude)
            let lon = String(format: "%.5f", stopData.longitude)
            addressLabel.text = "unknown address at (\(lat), \(lon))"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd. MMM HH:mm"

        let startDate = dateFormatter.string(from: stopData.start_time!)
        let endDate = dateFormatter.string(from: stopData.end_time!)
        startLabel.text = "\(startDate) - \(endDate)"
        
        let delta = stopData.start_time!.distance(to: stopData.end_time!)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute]
        endLabel.text = "Duration: \(formatter.string(from: delta)!)"
    }
}
