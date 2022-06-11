//
//  ViewController.swift
//  GPS Diary
//
//  Created by Robert Spang on 21.10.21.
//

import UIKit
import CoreLocation
import Contacts
import MapKit



class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var mapView: MKMapView!
    @IBOutlet var currentlyStoppedLabel: UILabel!
    @IBOutlet var positionAccuracyLabel: UILabel!
    @IBOutlet var startStopButton: UIButton!
    @IBOutlet var recordCountLabel: UILabel!
    @IBOutlet var stopsTabelView: UITableView!
    
    let timeIntervalFormatter = DateComponentsFormatter()
    let dayDateFormatter = DateFormatter()
    
    var currentlyStopped = false
    var preStopModality: String? = nil
    var currentLat = -1.0
    var currentLon = -1.0
    var currentAcc = -1.0
    var currentLocation = StopDataPoint(longitude: 0.0, latitude: 0.0, accuracy: 0.0, start_time: nil, end_time: nil)
    var savedStops: [StopDataPoint] = []
    var didUpdateDescriptions = false
    
    private var locationManager:CLLocationManager?
    
    
    
    // MARK: - object & interface

    override func viewDidLoad() {
        super.viewDidLoad()
        
        stopsTabelView.delegate = self
        stopsTabelView.dataSource = self
        
        locationManager = CLLocationManager()
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.delegate = self
        locationManager?.startUpdatingLocation()
        
        timeIntervalFormatter.unitsStyle = .abbreviated
        timeIntervalFormatter.zeroFormattingBehavior = .pad
        timeIntervalFormatter.allowedUnits = [.hour, .minute]
        
        dayDateFormatter.dateFormat = "d. MMM"
        
        loadData()
        updateUi()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUi()
        findMissingAddresses()
    }

    @IBAction func startStopButtonPressed(_ sender: Any) {
        if currentlyStopped {
            currentLocation.end_time = Date.now
            currentLocation.pre_stop_modality = preStopModality
            
            // reset flag
            currentlyStopped = false
            
            // ask for stop type
            // this saves the object as well - this is far from ideal and should be fixed!
            showStopTypeAlert()

        } else {
            // create new object
            currentLocation = StopDataPoint(
                longitude: currentLon,
                latitude: currentLat,
                accuracy: currentAcc,
                start_time: Date.now,
                end_time: nil,
                pre_stop_modality: nil
            )
            
            // resolve address
            addressLoockup(stopLocation: currentLocation)
            
            // set flag
            currentlyStopped = true
            
            // ask for transport modality
            showTransportModalityAlert()
            
            // save to disk
            try! saveData()
            updateUi()
        }
    }
    
    @IBAction func exportButtonPressed(_ sender: Any) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        
        // create CSV record row
        let csvRows = savedStops.map { stopDataPoint -> String in
            let start = formatter.string(from: stopDataPoint.start_time!)
            let end = formatter.string(from: stopDataPoint.end_time!)
            let lon = stopDataPoint.longitude
            let lat = stopDataPoint.latitude
            let acc = stopDataPoint.accuracy
            let modality = stopDataPoint.pre_stop_modality ?? "undefined"
            let stopType = stopDataPoint.stop_type ?? "undefined"
            var desc = stopDataPoint.description ?? "unknown address"
            desc = desc.replacingOccurrences(of: "\n", with: " ")
            desc = desc.replacingOccurrences(of: ",", with: " ")
            return "\(start),\(end),\(lon),\(lat),\(acc),\(desc),\(modality),\(stopType)"
        }
        
        let csvFileContent = "start_time,end_time,longitude,latitude,accuracy,description,modality,stop_type\n" + csvRows.joined(separator: "\n")
        shareResultsAsFile(csvFileContent: csvFileContent)
    }
    
    func shareResultsAsFile(csvFileContent: String) {
        // create filename
        let calendar = Calendar.current
        let dateString = "\(calendar.component(.year, from: Date.now))-\(calendar.component(.month, from: Date.now))-\(calendar.component(.day, from: Date.now))"
        let csvFilename = "\(dateString)_GPS_diary.csv"
        
        // write file & open share view
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(csvFilename)
            
            do {
                try csvFileContent.write(to: fileURL, atomically: false, encoding: .utf8)
                
                let objectsToShare = [fileURL]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityVC, animated: true, completion: nil)
            }
            catch {
                print("error while writing file")
            }
        }
    }

    func updateUi() {
        if currentlyStopped {
            // update button title
            startStopButton.setTitle("Depart from the current position", for: .normal)

            // set background color
            startStopButton.backgroundColor = UIColor(red: 242/255, green: 90/255, blue: 56/255, alpha: 1.0)
            
        } else {
            // update button title
            startStopButton.setTitle("Check-in at the current position", for: .normal)
            
            // set background color
            startStopButton.backgroundColor = UIColor(red: 3/255, green: 140/255, blue: 140/255, alpha: 1.0)
        }
        
        // update status label
        updateStatusLabel()
        
        // update tabel
        stopsTabelView.reloadData()
    }
    
    func updateStatusLabel() {
        if currentlyStopped {
            let delta = currentLocation.start_time!.distance(to: Date.now)
            currentlyStoppedLabel.text = "ckecked-in for \(timeIntervalFormatter.string(from: delta)!)"
            currentlyStoppedLabel.textColor = UIColor(red: 242/255, green: 90/255, blue: 56/255, alpha: 1.0)
            
        } else {
            currentlyStoppedLabel.text = "not tracking"
            currentlyStoppedLabel.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        }
        
        recordCountLabel.text = "Recorded \(savedStops.count) stops in total"
    }
    
    func loadData() {
        let defaults = UserDefaults.standard
        if let encodedStops = defaults.object(forKey: "SavedStopList") as? Data {
            let decoder = JSONDecoder()
            if let stops = try? decoder.decode([StopDataPoint].self, from: encodedStops) {
                savedStops = stops
            }
        }
        
        if let encodedCurrentLocation = defaults.object(forKey: "currentLocation") as? Data {
            let decoder = JSONDecoder()
            if let stop = try? decoder.decode(StopDataPoint.self, from: encodedCurrentLocation) {
                currentLocation = stop
            }
        }
        
        currentlyStopped = defaults.bool(forKey: "currentlyStopped")
        preStopModality = defaults.string(forKey: "preStopModality")
    }
    
    func saveData() throws {
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        
        if let encoded = try? encoder.encode(savedStops) {
            defaults.set(encoded, forKey: "SavedStopList")
        }
        
        if let encoded = try? encoder.encode(currentLocation) {
            defaults.set(encoded, forKey: "currentLocation")
        }
        
        defaults.set(currentlyStopped, forKey: "currentlyStopped")
        defaults.set(preStopModality, forKey: "preStopModality")
    }
    
    
    // MARK: - location manager
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let coordinateRegion = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            
            mapView.setRegion(coordinateRegion, animated: true)

            positionAccuracyLabel.text = "Accuracy: \(Int(location.horizontalAccuracy))m"
            
            // update current location object
            currentLat = location.coordinate.latitude
            currentLon = location.coordinate.longitude
            currentAcc = location.horizontalAccuracy
            
            // update status label
            updateStatusLabel()
        }
    }



    
    // MARK: - table view

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let idx = getArrayIndexFor(indexPath: indexPath) {
            let stopToDisplay = savedStops[idx]
            
            if let viewController = storyboard?.instantiateViewController(identifier: "StopViewController") as? StopViewController {
                viewController.stop = stopToDisplay
                viewController.stopIndex = idx
                viewController.mainVc = self

                navigationController?.pushViewController(viewController, animated: true)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionsFromStops().count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(rowsInSection(section: section).count) records from \(sectionsFromStops()[section])"
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 63.0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowsInSection(section: section).count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stopCell", for: indexPath) as! StopTableViewCell
        let relevantStops = rowsInSection(section: indexPath.section)
        cell.setupLabels(stopData: relevantStops[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            // identify & remove the element from the array
            if let idx = getArrayIndexFor(indexPath: indexPath) {
                savedStops.remove(at: idx)
            }
            
            // save to disk
            try! saveData()
            
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    func sectionsFromStops() -> [String] {
        let dates = savedStops.map { stop -> String in
            return dayDateFormatter.string(from: stop.start_time!)
        }

        return dates.unique()
    }
    
    func rowsInSection(section: Int) -> [StopDataPoint] {
        let sectionDate = sectionsFromStops()[section]
        return savedStops.filter { stop in
            dayDateFormatter.string(from: stop.start_time!) == sectionDate
        }
    }
    
    func getArrayIndexFor(indexPath: IndexPath) -> Int? {
        let deletedElement = rowsInSection(section: indexPath.section)[indexPath.row]
        return savedStops.firstIndex { stop in
            stop.start_time == deletedElement.start_time && stop.end_time == deletedElement.end_time
        }
    }
    
    
    // MARK: - address lookup
    
    func findMissingAddresses() {
        didUpdateDescriptions = false

        for (idx, stop) in savedStops.enumerated() {
            if stop.description == nil {
                addressLoockup(stopLocation: stop, updateIndex: idx)
            }
        }
        
        if didUpdateDescriptions {
            // save to disk
            try! saveData()
        }
    }
    
    func addressLoockup(stopLocation: StopDataPoint, updateIndex: Int? = nil) {
        let location = CLLocation(latitude: stopLocation.latitude, longitude: stopLocation.longitude)
        let geocoder = CLGeocoder()
                   
       // Look up the location and pass it to the completion handler
       geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in
           if error == nil {
               let firstLocation = placemarks?[0]
               self.updateLocation(placemark: firstLocation, updateIndex: updateIndex)
           }
       })
    }
    
    func updateLocation(placemark: CLPlacemark?, updateIndex: Int?) {
        if let place = placemark {
            if let postalAddress = place.postalAddress {
                let formatter = CNPostalAddressFormatter()
                let addressString = formatter.string(from: postalAddress).components(separatedBy: .whitespacesAndNewlines).joined(separator: " ")

                if let arrayIndex = updateIndex {
                    // update element in list
                    savedStops[arrayIndex].description = addressString
                    didUpdateDescriptions = true

                } else {
                    // update current location
                    currentLocation.description = addressString
                }

                // update tabel
                stopsTabelView.reloadData()
            }
        }
    }
    
    // MARK: - modality annotation
    
    func showTransportModalityAlert() {
        let alert = UIAlertController(title: "Modality", message: "Which transport modality describes your transit best?", preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: "walk", style: UIAlertAction.Style.default, handler: { _ in self.preStopModality = "walk" }))
        alert.addAction(UIAlertAction(title: "cycle", style: UIAlertAction.Style.default, handler: { _ in self.preStopModality = "cycle" }))
        alert.addAction(UIAlertAction(title: "car", style: UIAlertAction.Style.default, handler: { _ in self.preStopModality = "car" }))
        alert.addAction(UIAlertAction(title: "bus", style: UIAlertAction.Style.default, handler: { _ in self.preStopModality = "bus" }))
        alert.addAction(UIAlertAction(title: "train", style: UIAlertAction.Style.default, handler: { _ in self.preStopModality = "train" }))
        alert.addAction(UIAlertAction(title: "underground", style: UIAlertAction.Style.default, handler: { _ in self.preStopModality = "underground" }))
        alert.addAction(UIAlertAction(title: "diverse", style: UIAlertAction.Style.cancel, handler: { _ in self.preStopModality = "diverse" }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func showStopTypeAlert() {
        let alert = UIAlertController(title: "In or out?", message: "Did you dwell inside or outside?", preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: "inside", style: UIAlertAction.Style.default, handler: { _ in self.finalizeStopTypeSelection(stopType: "inside") }))
        alert.addAction(UIAlertAction(title: "outside but canopied", style: UIAlertAction.Style.default, handler: { _ in self.finalizeStopTypeSelection(stopType: "canopied") }))
        alert.addAction(UIAlertAction(title: "outside", style: UIAlertAction.Style.default, handler: { _ in self.finalizeStopTypeSelection(stopType: "outside") }))
        alert.addAction(UIAlertAction(title: "diverse", style: UIAlertAction.Style.cancel, handler: { _ in self.finalizeStopTypeSelection(stopType: "diverse") }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func finalizeStopTypeSelection(stopType: String) {
        currentLocation.stop_type = stopType
        
        // save element to list
        savedStops.insert(currentLocation, at: 0) // should be independent of the alert selection (e.g. moved back to startStopButtonPressed())
        
        // save to disk
        try! saveData() // should be independent of the alert selection (e.g. moved back to startStopButtonPressed())
        updateUi() // should be independent of the alert selection (e.g. moved back to startStopButtonPressed())
    }
    
}
