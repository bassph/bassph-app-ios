//
//  GeolocationService.swift
//  RxExample
//
//  Created by Carlos García on 19/01/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//
//  https://github.com/ReactiveX/RxSwift/blob/master/RxExample/RxExample/Services/GeolocationService.swift

import CoreLocation
import RxSwift
import RxCocoa

class GeolocationService {
    
    static let instance = GeolocationService()
    private (set) var authorized: Driver<Bool>
    private (set) var location: Driver<CLLocation>
    private (set) var lastLocation: CLLocation?
    private let disposeBag = DisposeBag()
    
    private let locationManager = CLLocationManager()
    
    private init() {
        
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        authorized = Observable.deferred { [weak locationManager] in
                let status = CLLocationManager.authorizationStatus()
                guard let locationManager = locationManager else {
                    return Observable.just(status)
                }
                return locationManager.rx
                    .didChangeAuthorizationStatus
                    .startWith(status)
            }
            .asDriver(onErrorJustReturn: CLAuthorizationStatus.notDetermined)
            .map {
                switch $0 {
                case .authorizedAlways:
                    return true
                default:
                    return false
                }
            }
        
        location = locationManager.rx
            .didUpdateLocations
            .asDriver(onErrorJustReturn: [])
            .flatMap {
                return $0.last.map(Driver.just) ?? Driver.empty()
            }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        location
            .asObservable()
            .subscribe {
                guard let element = $0.element else { return }
                self.lastLocation = element
            }
            .disposed(by: disposeBag)
    }
    
}
