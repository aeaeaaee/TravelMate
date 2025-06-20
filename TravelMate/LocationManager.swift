//
//  LocationManager.swift
//  TravelMate
//
//  Created by user277469 on 6/8/25.
//

import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
<<<<<<< HEAD
    
=======

>>>>>>> V2
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
<<<<<<< HEAD
        
=======

>>>>>>> V2
        // Start updating heading if available
        if CLLocationManager.headingAvailable() {
            self.locationManager.startUpdatingHeading()
        } else {
            print("Heading information is not available on this device.")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
<<<<<<< HEAD
    
=======

>>>>>>> V2
    // Delegate method for heading updates
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // We only want to receive heading updates if the accuracy is good
        // A negative value for headingAccuracy indicates that the heading is invalid
        print("DEBUG: didUpdateHeading called. True Heading: \(newHeading.trueHeading), Accuracy: \(newHeading.headingAccuracy)")
        if newHeading.headingAccuracy >= 0 {
            self.heading = newHeading
        } else {
            // Optionally, you can set heading to nil or handle the invalid heading case
            // For now, we'll just print a message and not update if accuracy is poor
            print("Received invalid heading update with accuracy: \(newHeading.headingAccuracy)")
        }
    }

    // Delegate method for handling errors with heading updates
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed with error: \(error.localizedDescription)")
        // You might want to handle specific errors, e.g., CLAuthorizationStatus.denied
        // or if heading updates fail for some reason.
    }
}
