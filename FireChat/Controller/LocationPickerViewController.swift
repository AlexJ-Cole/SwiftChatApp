//
//  LocationPickerViewController.swift
//  FireChat
//
//  Created by Alex Cole on 10/5/20.
//

import UIKit
import CoreLocation
import MapKit

/// Controller to present a map that allows users to place pin annotations and send selected location to another user. Also used to view sent locations when the message containing them is tapped on in `ChatViewController`
final class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    
    private var isPickable = true
    
    private var coordinates: CLLocationCoordinate2D?
    
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    init(coordinates: CLLocationCoordinate2D?) {
        if let coordinates = coordinates {
            self.coordinates = coordinates
            self.isPickable = false
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        if isPickable {
            //This means that the view controller is supposed to allow user to pick and send a location on the map
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            
            title = "Pick Location"
            
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            //Create pin on map marking location that was shared in conversation
            guard let coordinates = coordinates else {
                return
            }
            
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        
        view.addSubview(map)
        map.isUserInteractionEnabled = true
    }
    
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates else {
            return
        }
        
        completion?(coordinates)
        navigationController?.popViewController(animated: true)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        //Removes all current annotations (should only be one)
        map.removeAnnotations(map.annotations)
        
        //Drop a pin on tapped location so user can see where they have tapped
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        
        map.addAnnotation(pin)
    }
    
    override func viewDidLayoutSubviews() {
        map.frame = view.bounds
    }
}
