//
//  BandwidthTestHandler.swift
//  BASS
//
//  Created by Andrew on 08/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift
import RxAlamofire
import Dollar
import CoreLocation

class BandwidthTestHandler {
    
    static let instance = BandwidthTestHandler()

    enum Status {
        case idle
        case testing
        case testError
        case uploading
        case uploadError
        case completed
    }
    
    var speedTestUrl = "http://speedtest.singapore.linode.com/100MB-singapore.bin"
    var dataCapSizeInMB: Int = 5
    var testLengthInSeconds: TimeInterval = 10
    let samplingRateInSeconds: TimeInterval = 1
    
    private let disposeBag = DisposeBag()
    private let tracker = BytesTracker()
    private var downloadDisposable: Disposable? = nil
    private var lastTrackerBytesReceived: UInt64 = 0
    
    private (set) var currentLocation: CLLocation? = nil
    private (set) var downloadFailed = false
    private (set) var dataCapSizeReached = false
    private (set) var testLengthFinished = false
    private (set) var mbpsTracked = [Double]()
    private (set) var startTime = NSDate().timeIntervalSince1970
    private (set) var lastResult = [String : Any]()
    
    var onDownloadedMBUpdated = BehaviorSubject<Double>(value: 0)
    var onMbpsTracked = PublishSubject<Double>()
    var status = BehaviorSubject<Status>(value: .idle)
    
    private init() {
        GeolocationService.instance
            .location
            .asObservable()
            .subscribe { [weak self] in
                if let location = $0.element {
                    self?.currentLocation = location
                }
            }
            .addDisposableTo(disposeBag)
    }
    
    func startTest() {
        do {
            if try status.value() == .idle {
                onDownloadedMBUpdated.onNext(0)
                mbpsTracked.removeAll()
                downloadFailed = false
                dataCapSizeReached = false
                testLengthFinished = false
                lastTrackerBytesReceived = 0
                startTime = NSDate().timeIntervalSince1970
                run()
            }
        } catch {
            
        }
    }
    
    private func run() {
        status.onNext(.testing)
        
        downloadDisposable = RxAlamofire
            .request(.get, speedTestUrl)
            .flatMap { request -> Observable<RxProgress> in
                return request.rx.progress()
            }
            .observeOn(MainScheduler.instance)
            .skipWhile { $0.bytesWritten == 0 }
            .do(onNext: { [weak self] in
                let cap = Int64((self?.dataCapSizeInMB ?? 0) * 1048576)
                if cap > 0 && $0.bytesWritten > cap {
                    self?.dataCapSizeReached = true
                    self?.onDownloadedMBUpdated.onNext(Double($0.bytesWritten) / 1048576)
                    self?.downloadDisposable?.dispose()
                }
            }, onError: { [weak self] (error) in
                self?.downloadFailed = true
            })
            .throttle(1, scheduler: MainScheduler.instance)
            .subscribe { [weak self] in
                self?.onDownloadedMBUpdated.onNext(Double($0.element?.bytesWritten ?? 0) / 1048576)
            }
        
        tracker.track(seconds: 20)
            .do(onNext: { [weak self] (measure) in
                if let me = self {
                    if me.dataCapSizeReached || me.downloadFailed {
                        self?.tracker.cancel()
                    }
                }
            })
            .throttle(1, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                if let me = self {
                    let current = $0.bytesReceived
                    let period = current - me.lastTrackerBytesReceived
                    let mbps = (Double(period) / 1048576) * 8
                    me.lastTrackerBytesReceived = current
                    if mbps > 0 {
                        me.mbpsTracked.append(mbps)
                        me.onMbpsTracked.onNext(mbps)
                    }
                }
            }, onError: { [weak self] (error) in
                self?.status.onNext(.testError)
                self?.status.onNext(.idle)
            }, onCompleted: { [weak self] in
                if let me = self {
                    if !me.dataCapSizeReached && !me.downloadFailed {
                        me.testLengthFinished = true
                    }
                    if let disposable = me.downloadDisposable {
                        disposable.dispose()
                    }
                    if me.downloadFailed {
                        self?.status.onNext(.testError)
                        self?.status.onNext(.idle)
                    } else {
                        me.uploadResult()
                    }
                }
            })
            .addDisposableTo(disposeBag)
    }
    
    var maxMbps: Double {
        return $.max(mbpsTracked) ?? 0
    }
    
    private func getCurrentKbps() -> Int {
        return Int(($.max(mbpsTracked) ?? 0) * 1000)
    }
    
    private func getCurrentMBUsage() -> Double {
        do {
            return try onDownloadedMBUpdated.value()
        } catch {
            return 0
        }
    }
    
    private func uploadResult() {
        status.onNext(.uploading)

        let defaults = UserDefaults.standard
        var deviceId = defaults.string(forKey: "deviceId")
        if deviceId == nil || deviceId == "" {
            deviceId = UUID().uuidString.lowercased()
            defaults.set(deviceId, forKey: "deviceId")
        }

        let finishTime = NSDate().timeIntervalSince1970
        let carrier = NetworkHandler.getCarrierDetails()
        let device: [String : Any] = [
            "id": deviceId!.lowercased(),
            "platform": "iOS",
            "manufacturer": "Apple",
            "name": "iOS " + UIDevice.current.systemVersion,
            "model": UIDevice.current.type.rawValue,
            "release": UIDevice.current.systemVersion
        ]
        var location = [String : Any]()
        if let currentLocation = self.currentLocation {
            location["mAccuracy"] = currentLocation.horizontalAccuracy
            location["mAltitude"] = currentLocation.altitude
            location["mBearing"] = currentLocation.course
            location["mLatitude"] = currentLocation.coordinate.latitude
            location["mLongitude"] = currentLocation.coordinate.longitude
            location["mTime"] = currentLocation.timestamp.timeIntervalSince1970
            location["mElapsedRealtimeNanos"] = DispatchTime.now().uptimeNanoseconds
            location["mSpeed"] = currentLocation.speed
            location["mFieldMask"] = 8
            location["mProvider"] = "fused"
        }
        let connectivity: [String : Any] = [
            "available": true,
            "detailedState": "CONNECTED",
            "failover": false,
            "roaming": false,
            "state": "CONNECTED",
            "subType": NetworkHandler.getAndroidNetworkSubType(),
            "subTypeName": NetworkHandler.getAndroidNetworkSubTypeName(),
            "type": NetworkHandler.getAndroidNetworkType(),
            "typeName": NetworkHandler.getAndroidNetworkTypeName(),
            "extraInfo": NetworkHandler.getWifiSSID() ?? "",
        ]
        let testData: [String : Any] = [
            "startTime": startTime,
            "finishTime": finishTime,
            "duration": finishTime - startTime,
            "mbUsage": getCurrentMBUsage(),
            "mbpsTracked": mbpsTracked
        ]
        
        let signalBars = NetworkHandler.getCellSignalStrength()
        var signalDB = 0
        switch signalBars {
        case 5: signalDB = -51
        case 4: signalDB = -91
        case 3: signalDB = -101
        case 2: signalDB = -103
        case 1: signalDB = -107
        default: signalDB = -113
        }
        var signalType = NetworkHandler.getRadioAccessTechnology()
        if signalType == "" {
            signalType = "NONE"
        }
        
        let parameters: [String : Any] = [
            "uuid": UUID().uuidString.lowercased(),
            "time": finishTime,
            "bandwidth": "\(getCurrentKbps()) Kbps",
            "operator": carrier["name"] ?? "",
            "carrier": carrier,
            "signal": "\(signalType) : \(signalDB)",
            "signalBars": signalBars,
            "device": device,
            "location": location,
            "connectivity": connectivity,
            "testData": testData,
            "imei": "none"
        ]
        
        lastResult = parameters
        startUpload(parameters)
    }
    
    private func startUpload(_ parameters: [String : Any]) {
        do {
            let json = try JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions.prettyPrinted)
            print("JSON: \(String(data: json, encoding: .utf8)!)")
        } catch {
            
        }
        let url = "https://bass.bnshosting.net/api/record"
        RxAlamofire
            .request(.post, url, parameters: parameters, encoding: JSONEncoding.default)
            .subscribe(onNext: { (request) in
                request.validate().responseJSON(completionHandler: { (response) in
                    switch response.result {
                    case .success:
                        if let json = response.result.value {
                            print("Response: \(json)")
                        }
                        break
                    case .failure(_):
                        if let data = response.data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data)
                                print("Error: \(json)")
                            } catch {
                                
                            }
                        }
                        break
                    }
                })
            }, onError: { [weak self] (error) in
                print(error)
                self?.status.onNext(.uploadError)
                self?.status.onNext(.idle)
                }, onCompleted: { [weak self] in
                    self?.status.onNext(.completed)
                    self?.status.onNext(.idle)
            })
            .addDisposableTo(disposeBag)
    }
}
