//
//  ResultHandler.swift
//  BASS
//
//  Created by Andrew Alegre on 04/10/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxAlamofire
import Alamofire
import SwiftyJSON

class ResultHandler {
    
    static func generateMapped(with result: BandwidthTestResult, andMood mood: Int) -> [String : Any] {
        let defaults = UserDefaults.standard
        var deviceId = defaults.string(forKey: "deviceId")
        if deviceId == nil || deviceId == "" {
            deviceId = UUID().uuidString.lowercased()
            defaults.set(deviceId, forKey: "deviceId")
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let appBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        
        let carrier = NetworkHandler.getCarrierDetails()
        let device: [String : Any] = [
            "id": deviceId!.lowercased(),
            "platform": "iOS",
            "manufacturer": "Apple",
            "name": "iOS " + UIDevice.current.systemVersion,
            "model": UIDevice.current.type.rawValue,
            "release": UIDevice.current.systemVersion,
            "appVersion": appVersion,
            "appBuildNumber": appBuildNumber
        ]
        var location = [String : Any]()
        if let currentLocation = result.location {
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
            "extraInfo": NetworkHandler.getWifiSSID() ?? ""
        ]
        
        let testData: [String : Any] = [
            "startTime": result.startTime,
            "finishTime": result.finishTime,
            "duration": result.finishTime - result.startTime,
            "mbUsage": result.mbDownloaded,
            "mbpsTracked": result.mbpsTracked
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
            "time": result.finishTime,
            "bandwidth": "\(result.currentKbps) Kbps",
            "operator": carrier["name"] ?? "",
            "carrier": carrier,
            "signal": "\(signalType) : \(signalDB)",
            "signalBars": signalBars,
            "device": device,
            "location": location,
            "connectivity": connectivity,
            "testData": testData,
            "imei": "none",
            "version": appVersion,
            "mood": mood
        ]
        
        return parameters
    }
    
    static func uploadMappedResult(_ mapped: [String : Any]) -> Single<[String : Any]> {
        let recordUrl = "https://bass.bnshosting.net/api/v2/record"
        
        do {
            let json = try JSONSerialization.data(withJSONObject: mapped, options: JSONSerialization.WritingOptions.prettyPrinted)
            
            print("JSON: \(String(data: json, encoding: .utf8)!)")
            
        } catch {
            
        }
        
        return RxAlamofire
            .request(.post, recordUrl, parameters: mapped, encoding: JSONEncoding.default)
            .flatMap { $0.validate().rx.string() }
            .observeOn(MainScheduler.instance)
            .map { _ in mapped }
            .asSingle()
    }
    
}
