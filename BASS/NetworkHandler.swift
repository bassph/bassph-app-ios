//
//  NetworkHandler.swift
//  BASS
//
//  Created by Andrew on 07/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import Dollar
import RxSwift
import ReachabilitySwift
import CoreTelephony
import SystemConfiguration.CaptiveNetwork

struct NetworkMeasurement {
    var bytesReceived: UInt64 = 0
    var bytesSent: UInt64 = 0
}

class BytesTracker {
    
    var measure = NetworkMeasurement()
    
    private var publishSubject: PublishSubject<NetworkMeasurement>? = nil
    private var trackingTimer: Timer? = nil
    private var pollingTimer: Timer? = nil
    private var rxMap = [String : UInt32]()
    private var txMap = [String : UInt32]()
    private var currentPrefix: String = "*"
    private var isTracking = false
    
    private func startTracking(_ timeInterval: TimeInterval) {
        finishTracking()
        isTracking = true
        
        if let reachability = Reachability() {
            switch reachability.currentReachabilityStatus {
            case .reachableViaWiFi: currentPrefix = "en"
            case .reachableViaWWAN: currentPrefix = "pdp_ip"
            default: currentPrefix = "*"
            }
        }
        
        publishSubject = PublishSubject<NetworkMeasurement>()
        measure = NetworkMeasurement()
        
        let interfaces = NetworkHandler.getAllNetworkInterfaceInfo()
        fillCacheWith(interfaces)
        
        pollingTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(onTrack), userInfo: nil, repeats: true)
        trackingTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(finishTracking), userInfo: nil, repeats: false)
    }
    
    @objc private func finishTracking() {
        if isTracking {
            trackingTimer?.invalidate()
            pollingTimer?.invalidate()
            publishSubject?.onCompleted()
            rxMap.removeAll()
            txMap.removeAll()
            trackingTimer = nil
            pollingTimer = nil
            publishSubject = nil
            isTracking = false
        }
    }
    
    @objc private func onTrack() {
        let interfaces = NetworkHandler.getAllNetworkInterfaceInfo(prefix: self.currentPrefix)
        measure.bytesReceived += getBytesReceivedSinceLast(interfaces)
        measure.bytesSent += getBytesSentSinceLast(interfaces)
        
        fillCacheWith(interfaces)
        publishSubject?.onNext(measure)
    }
    
    func track(seconds timeInterval: TimeInterval) -> Observable<NetworkMeasurement> {
        startTracking(timeInterval)
        return publishSubject!
    }
    
    func cancel() {
        finishTracking()
    }
    
    func fillCacheWith(_ interfaces: [NetworkInterfaceInfo]) {
        for interface in interfaces {
            rxMap[interface.name] = interface.bytesReceived
            txMap[interface.name] = interface.bytesSent
        }
    }
    
    func getBytesReceivedSinceLast(_ interfaces: [NetworkInterfaceInfo]) -> UInt64 {
        return $.reduce($.map(interfaces, transform: { getDifference(rxMap[$0.name] ?? $0.bytesReceived, $0.bytesReceived) }),
                        initial: UInt64(0), combine: { sum, x in sum + x })
    }
    
    func getBytesSentSinceLast(_ interfaces: [NetworkInterfaceInfo]) -> UInt64 {
        return  $.reduce($.map(interfaces, transform: { getDifference(txMap[$0.name] ?? $0.bytesSent, $0.bytesSent) }),
                         initial: UInt64(0), combine: { sum, x in sum + x })
    }
    
    func getDifference(_ last: UInt32, _ next: UInt32) -> UInt64 {
        if (last > next) {
            return UInt64((UINT32_MAX - last) + next)
        } else {
            return UInt64(next - last)
        }
    }
    
}

struct NetworkInterfaceInfo {
    var name: String
    var bytesReceived: UInt32 = 0
    var bytesSent: UInt32 = 0
}

class NetworkHandler {
    
    class func getAllNetworkInterfaceInfo() -> [NetworkInterfaceInfo] {
        var list = [NetworkInterfaceInfo]()
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&interfaceAddresses) == 0 else { return list }
        var pointer = interfaceAddresses
        while pointer != nil {
            if let currentPointer = pointer {
                if let info = getNetworkInterfaceInfo(from: currentPointer) {
                    list.append(info)
                }
                pointer = currentPointer.pointee.ifa_next
            }
        }
        freeifaddrs(interfaceAddresses)
        return list
    }
    
    class func getAllNetworkInterfaceInfo(prefix: String) -> [NetworkInterfaceInfo] {
        var list = [NetworkInterfaceInfo]()
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&interfaceAddresses) == 0 else { return list }
        var pointer = interfaceAddresses
        while pointer != nil {
            if let currentPointer = pointer {
                let name = String(cString: currentPointer.pointee.ifa_name)
                if name.hasPrefix(prefix) {
                    if let info = getNetworkInterfaceInfo(from: currentPointer) {
                        list.append(info)
                    }
                }
                pointer = currentPointer.pointee.ifa_next
            }
        }
        freeifaddrs(interfaceAddresses)
        return list
    }
    
    private class func getNetworkInterfaceInfo(from pointer: UnsafeMutablePointer<ifaddrs>) -> NetworkInterfaceInfo? {
        let addr = pointer.pointee.ifa_addr.pointee
        guard addr.sa_family == UInt8(AF_LINK) else { return nil }
        let networkData = unsafeBitCast(pointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
        return NetworkInterfaceInfo(name: String(cString: pointer.pointee.ifa_name),
                                    bytesReceived: networkData.pointee.ifi_ibytes,
                                    bytesSent: networkData.pointee.ifi_obytes)
    }
    
    class func getCarrierDetails() -> [String: String] {
        var details = [String: String]()
        let info = CTTelephonyNetworkInfo()
        if let carrier = info.subscriberCellularProvider {
            details["voip"] = carrier.allowsVOIP.description
            details["name"] = carrier.carrierName ?? ""
            details["icc"] = carrier.isoCountryCode ?? ""
            details["mcc"] = carrier.mobileCountryCode ?? ""
            details["mnc"] = carrier.mobileNetworkCode ?? ""
        }
        return details
    }
    
    // http://stackoverflow.com/a/41170417
    class func getCellSignalStrength() -> Int {
        let application = UIApplication.shared
        let statusBarView = application.value(forKey: "statusBar") as! UIView
        let foregroundView = statusBarView.value(forKey: "foregroundView") as! UIView
        let foregroundViewSubviews = foregroundView.subviews
        
        var dataNetworkItemView: UIView!
        for subview in foregroundViewSubviews {
            if subview.isKind(of: NSClassFromString("UIStatusBarSignalStrengthItemView")!) {
                dataNetworkItemView = subview
                break
            } else {
                return 0 //NO SERVICE
            }
        }
        
        return dataNetworkItemView.value(forKey: "signalStrengthBars") as! Int
    }
    
    class func getRadioAccessTechnology() -> String {
        let networkInfo = CTTelephonyNetworkInfo()
        let carrierType = networkInfo.currentRadioAccessTechnology
        switch carrierType {
        case CTRadioAccessTechnologyGPRS?,
             CTRadioAccessTechnologyEdge?: return "GSM"
        case CTRadioAccessTechnologyCDMA1x?: return "CDMA"
        case CTRadioAccessTechnologyWCDMA?,
             CTRadioAccessTechnologyHSDPA?,
             CTRadioAccessTechnologyHSUPA?,
             CTRadioAccessTechnologyCDMAEVDORev0?,
             CTRadioAccessTechnologyCDMAEVDORevA?,
             CTRadioAccessTechnologyCDMAEVDORevB?,
             CTRadioAccessTechnologyeHRPD?: return "WCDMA"
        case CTRadioAccessTechnologyLTE?: return "LTE"
        default: return ""
        }
    }
    
    class func getConnectivity() -> String {
        if let reachability = Reachability() {
            switch reachability.currentReachabilityStatus {
            case .reachableViaWiFi: return "WIFI"
            case .reachableViaWWAN:
                switch getRadioAccessTechnology() {
                case "GSM", "CDMA": return "2G"
                case "WCDMA": return "3G"
                case "LTE": return "4G"
                default: return ""
                }
            default: return ""
            }
        }
        return ""
    }

    class func getWifiSSID() -> String? {
        var currentSSID: String? = nil
        if let interfaces = CNCopySupportedInterfaces() {
            for i in 0..<CFArrayGetCount(interfaces) {
                let interfaceName: UnsafeRawPointer = CFArrayGetValueAtIndex(interfaces, i)
                let rec = unsafeBitCast(interfaceName, to: AnyObject.self)
                let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)" as CFString)
                if unsafeInterfaceData != nil {
                    let interfaceData = unsafeInterfaceData! as Dictionary!
                    currentSSID = interfaceData?["SSID" as CFString] as? String
                }
            }
        }
        return currentSSID
    }
    
    class func getAndroidNetworkSubType() -> Int {
        let networkInfo = CTTelephonyNetworkInfo()
        let carrierType = networkInfo.currentRadioAccessTechnology
        switch carrierType {
        case CTRadioAccessTechnologyGPRS?: return 1
        case CTRadioAccessTechnologyEdge?: return 2
        case CTRadioAccessTechnologyCDMA1x?: return 4
        case CTRadioAccessTechnologyWCDMA?: return 3
        case CTRadioAccessTechnologyHSDPA?: return 8
        case CTRadioAccessTechnologyHSUPA?: return 9
        case CTRadioAccessTechnologyCDMAEVDORev0?: return 5
        case CTRadioAccessTechnologyCDMAEVDORevA?: return 6
        case CTRadioAccessTechnologyCDMAEVDORevB?: return 12
        case CTRadioAccessTechnologyeHRPD?: return 14
        case CTRadioAccessTechnologyLTE?: return 13
        default: return 0
        }
    }
    
    class func getAndroidNetworkSubTypeName() -> String {
        let networkInfo = CTTelephonyNetworkInfo()
        let carrierType = networkInfo.currentRadioAccessTechnology
        switch carrierType {
        case CTRadioAccessTechnologyGPRS?: return "GPRS"
        case CTRadioAccessTechnologyEdge?: return "EDGE"
        case CTRadioAccessTechnologyCDMA1x?: return "CDMA"
        case CTRadioAccessTechnologyWCDMA?: return "WCDMA"
        case CTRadioAccessTechnologyHSDPA?: return "HSDPA"
        case CTRadioAccessTechnologyHSUPA?: return "HSUPA"
        case CTRadioAccessTechnologyCDMAEVDORev0?: return "EVDO-0"
        case CTRadioAccessTechnologyCDMAEVDORevA?: return "EVDO-A"
        case CTRadioAccessTechnologyCDMAEVDORevB?: return "EVDO-B"
        case CTRadioAccessTechnologyeHRPD?: return "EHRPD"
        case CTRadioAccessTechnologyLTE?: return "LTE"
        default: return ""
        }
    }
    
    class func getAndroidNetworkType() -> Int {
        let connectivity = NetworkHandler.getConnectivity()
        switch connectivity {
        case "WIFI": return 1
        default: return 0
        }
    }
    
    class func getAndroidNetworkTypeName() -> String {
        let connectivity = NetworkHandler.getConnectivity()
        switch connectivity {
        case "WIFI": return "WIFI"
        default: return "MOBILE"
        }
    }
    
}
