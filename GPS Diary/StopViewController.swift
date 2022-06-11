//
//  ViewController.swift
//  GPS Diary
//
//  Created by Robert Spang on 21.10.21.
//

import UIKit



class StopViewController: UIViewController {
    
    @IBOutlet var addressLabel: UILabel!
    @IBOutlet var startDateLabel: UILabel!
    @IBOutlet var endDateLabel: UILabel!
    @IBOutlet var preStopModalityLabel: UILabel!
    @IBOutlet var stopTypeLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    
    var stop: StopDataPoint?
    var originalStartDate = Date.now
    var originalEndDate = Date.now
    var stopIndex = -1
    var mainVc: ViewController?
    
    let dateFormatter = DateFormatter()
    
    
    
    // MARK: - object & interface

    override func viewDidLoad() {
        super.viewDidLoad()
        
        originalStartDate = stop!.start_time!
        originalEndDate = stop!.end_time!
        
        if let description = stop!.description {
            addressLabel.text = description
        } else {
            let lat = String(format: "%.5f", stop!.latitude)
            let lon = String(format: "%.5f", stop!.longitude)
            addressLabel.text = "unknown address at (\(lat), \(lon))"
        }
        
        preStopModalityLabel.text = "pre stop modality: \(stop!.pre_stop_modality ?? "undefined")"
        stopTypeLabel.text = "stop type: \(stop!.stop_type ?? "undefined")"
        
        dateFormatter.dateFormat = "dd. MMM, HH:mm:ss"
        saveButton.tintColor = .white
        saveButton.backgroundColor = UIColor(red: 242/255, green: 90/255, blue: 56/255, alpha: 1.0)
        saveButton.isHidden = true
        update()
    }
    
    @IBAction func startMinus30(_ sender: Any) {
        stop!.start_time = stop!.start_time! - 180
        update()
    }
    
    @IBAction func startMinus15(_ sender: Any) {
        stop!.start_time = stop!.start_time! - 15
        update()
    }
    
    @IBAction func startPlus15(_ sender: Any) {
        stop!.start_time = stop!.start_time! + 15
        update()
    }
    
    @IBAction func startPlus30(_ sender: Any) {
        stop!.start_time = stop!.start_time! + 180
        update()
    }
    
    @IBAction func endMinus30(_ sender: Any) {
        stop!.end_time = stop!.end_time! - 180
        update()
    }
    
    @IBAction func endMinus15(_ sender: Any) {
        stop!.end_time = stop!.end_time! - 15
        update()
    }
    
    @IBAction func endPlus15(_ sender: Any) {
        stop!.end_time = stop!.end_time! + 15
        update()
    }
    
    @IBAction func endPlus30(_ sender: Any) {
        stop!.end_time = stop!.end_time! + 180
        update()
    }
    
    @IBAction func saveStopButtonTapped(_ sender: Any) {
        if let parent = mainVc {
            parent.savedStops[stopIndex] = stop!
            _ = navigationController?.popToRootViewController(animated: true)
        }
    }
    
    func update() {
        startDateLabel.text = dateFormatter.string(from: stop!.start_time!)
        endDateLabel.text = dateFormatter.string(from: stop!.end_time!)
        
        let changedStart = originalStartDate != stop!.start_time!
        let changedEnd = originalEndDate != stop!.end_time!
        saveButton.isHidden = !(changedStart || changedEnd)
    }
}
