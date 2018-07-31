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
import Reachability
import CoreTelephony
import SystemConfiguration.CaptiveNetwork
import Try

struct NetworkMeasurement {
    var bytesReceived: UInt64 = 0
    var bytesSent: UInt64 = 0
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
        do {
            var statusBarView: UIView!
            var foregroundView: UIView!
            var value: Int = -1
            try trap {
                let application = UIApplication.shared
                statusBarView = application.value(forKey: "statusBar") as! UIView
                foregroundView = statusBarView.value(forKey: "foregroundView") as! UIView
                let foregroundViewSubviews = foregroundView.subviews
                var dataNetworkItemView: UIView!
                for subview in foregroundViewSubviews {
                    if subview.isKind(of: NSClassFromString("UIStatusBarSignalStrengthItemView")!) {
                        dataNetworkItemView = subview
                        break
                    } else {
                        value = 0 // NO SERVICE
                    }
                }
                value = dataNetworkItemView.value(forKey: "signalStrengthBars") as! Int
            }
            return value
        } catch _ as NSError {
            return -1
        }
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
            switch reachability.connection {
            case .wifi: return "WIFI"
            case .cellular:
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
                    let interfaceData = unsafeInterfaceData! as Dictionary
                    currentSSID = interfaceData["SSID" as CFString] as? String
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
