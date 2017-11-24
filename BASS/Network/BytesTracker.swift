//
//  BytesTracker.swift
//  BASS
//
//  Created by Andrew Alegre on 04/10/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import Dollar
import RxSwift
import Reachability

struct BytesTrackerData {
    var timestamp: NSDate
    var bytesReceivedSinceLast: UInt64
    var bytesSentSinceLast: UInt64
    var bytesReceivedTotal: UInt64
    var bytesSentTotal: UInt64
    var sampleIndex: UInt32
}

class BytesTrackerSession {
    
    init(selector: @escaping (NetworkInterfaceInfo) -> Bool) {
        self.selector = selector
    }
    
    var selector: (NetworkInterfaceInfo) -> Bool
    var initialRxMap = [String: UInt32]()
    var initialTxMap = [String: UInt32]()
    var lastRxMap = [String: UInt32]()
    var lastTxMap = [String: UInt32]()
    
    var bytesReceivedSinceLast = UInt64(0)
    var bytesSentSinceLast = UInt64(0)
    var bytesReceivedTotal = UInt64(0)
    var bytesSentTotal = UInt64(0)
    
    func updateCacheWith(_ interfaces: [NetworkInterfaceInfo]) {
        bytesReceivedSinceLast = getBytesReceivedSinceLast(interfaces)
        bytesSentSinceLast = getBytesSentSinceLast(interfaces)
        bytesReceivedTotal = getBytesReceivedTotal(interfaces)
        bytesSentTotal = getBytesSentTotal(interfaces)
        fillLastCacheWith(interfaces)
    }
    
    func fillInitialCacheWith(_ interfaces: [NetworkInterfaceInfo]) {
        for interface in interfaces {
            initialRxMap[interface.name] = interface.bytesReceived
            initialTxMap[interface.name] = interface.bytesSent
        }
    }
    
    func fillLastCacheWith(_ interfaces: [NetworkInterfaceInfo]) {
        for interface in interfaces {
            lastRxMap[interface.name] = interface.bytesReceived
            lastTxMap[interface.name] = interface.bytesSent
        }
    }
    
    func getBytesReceivedSinceLast(_ interfaces: [NetworkInterfaceInfo]) -> UInt64 {
        return `$`.reduce(`$`.map(interfaces.filter(selector), transform: { getDifference(lastRxMap[$0.name] ?? $0.bytesReceived, $0.bytesReceived) }), initial: UInt64(0), combine: { sum, x in sum + x })
    }
    
    func getBytesSentSinceLast(_ interfaces: [NetworkInterfaceInfo]) -> UInt64 {
        return  `$`.reduce(`$`.map(interfaces.filter(selector), transform: { getDifference(lastTxMap[$0.name] ?? $0.bytesSent, $0.bytesSent) }), initial: UInt64(0), combine: { sum, x in sum + x })
    }
    
    func getBytesReceivedTotal(_ interfaces: [NetworkInterfaceInfo]) -> UInt64 {
        return `$`.reduce(`$`.map(interfaces.filter(selector), transform: { getDifference(initialRxMap[$0.name] ?? $0.bytesReceived, $0.bytesReceived) }), initial: UInt64(0), combine: { sum, x in sum + x })
    }
    
    func getBytesSentTotal(_ interfaces: [NetworkInterfaceInfo]) -> UInt64 {
        return  `$`.reduce(`$`.map(interfaces.filter(selector), transform: { getDifference(initialTxMap[$0.name] ?? $0.bytesSent, $0.bytesSent) }), initial: UInt64(0), combine: { sum, x in sum + x })
    }
    
    func getDifference(_ last: UInt32, _ next: UInt32) -> UInt64 {
        if (last > next) {
            return UInt64((UINT32_MAX - last) + next)
        } else {
            return UInt64(next - last)
        }
    }
}

class BytesTracker {
    
    static func start(period: TimeInterval) -> Observable<BytesTrackerData> {
        
        var selector: (NetworkInterfaceInfo) -> Bool
        if let reachability = Reachability() {
            switch reachability.connection {
            case .wifi: selector = { $0.name.starts(with: "en") }
            case .cellular: selector = { $0.name.starts(with: "pdp_ip") }
            default: selector = { $0.name.starts(with: "pdp_ip") || $0.name.starts(with: "en") }
            }
        } else {
            selector = { $0.name.starts(with: "pdp_ip") || $0.name.starts(with: "en") }
        }
        
        let session = BytesTrackerSession(selector: selector)
        session.fillInitialCacheWith(NetworkHandler.getAllNetworkInterfaceInfo())
        
        return Observable<UInt32>
            .interval(period, scheduler: MainScheduler.instance)
            .map {
                session.updateCacheWith(NetworkHandler.getAllNetworkInterfaceInfo())
                return BytesTrackerData(timestamp: NSDate(),
                                        bytesReceivedSinceLast: session.bytesReceivedSinceLast,
                                        bytesSentSinceLast: session.bytesSentSinceLast,
                                        bytesReceivedTotal: session.bytesReceivedTotal,
                                        bytesSentTotal: session.bytesSentTotal,
                                        sampleIndex: $0)
            }
    }
    
}
