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
import Dollar
import CoreLocation
import SwiftyJSON
import RxAlamofire

struct BandwidthTestParameters {
    var url = "http://speedtest.pregi.net/ubuntu-17.04-server-amd64.iso"
    var duration = 15.0
    var trackingRate = 1.0
    var downloadCapSizeInMB = 100.0
    var uploadCapSizeInMB = 100.0
}

struct BandwidthTestEvents {
    var onStart: Single<NSDate>
    var onFinish: Single<BandwidthTestResult>
    
    var onMbpsTracked: Observable<Double>
    var onMaxMbpsTracked: Observable<Double>
    var onDownloadedMBTracked: Observable<Double>
    
    var initializer: (DisposeBag) -> Void
    
    func begin(with disposeBag: DisposeBag) {
        initializer(disposeBag)
    }
}

struct BandwidthTestData {
    var downloadProgress: RxProgress?
    var trackedData: BytesTrackerData?
    var location: CLLocation?
}

class BandwidthTestResult {
    
    var startTime = NSDate().timeIntervalSince1970
    var finishTime = NSDate().timeIntervalSince1970
    var location: CLLocation? = nil
    var mbpsTracked = [Double]()
    var mbDownloaded = 0.0
    
    var maxMbps: Double {
        return `$`.max(mbpsTracked) ?? 0
    }
    
    var currentKbps: Int {
        return Int(ceil(maxMbps * 1000.0))
    }
    
}
class BandwidthTestHandler {
    
    static func start(with parameters: BandwidthTestParameters) -> Observable<BandwidthTestData> {
        let downloadRequest = RxAlamofire
            .request(.get, parameters.url)
            .flatMap { $0.rx.progress() }
            .skipWhile { $0.bytesWritten == 0 }
            .takeWhile {
                let capSize = parameters.downloadCapSizeInMB
                let capSizeBytes = Int64(ceil(parameters.downloadCapSizeInMB * 1048576))
                return capSize > 0.0 && $0.bytesWritten < capSizeBytes
            }
            .throttle(1, scheduler: MainScheduler.instance)
        
        let bytesTracker = BytesTracker
            .start(period: parameters.trackingRate)
        
        return Observable
            .combineLatest(downloadRequest, bytesTracker) {
                return BandwidthTestData(downloadProgress: $0, trackedData: $1, location: GeolocationService.instance.lastLocation)
            }
            .skipWhile { ($0.trackedData?.bytesReceivedSinceLast ?? 0) == 0 }
            .take(parameters.duration, scheduler: MainScheduler.instance)
    }
    
    static func prepareObserving(with parameters: BandwidthTestParameters) -> BandwidthTestEvents {
        let rxBandwidthTest = start(with: parameters)
            .observeOn(MainScheduler.instance)
            .publish()
        
        let result = BandwidthTestResult()
        
        let rxMbpsResults = rxBandwidthTest
            .map { Double($0.trackedData?.bytesReceivedSinceLast ?? 0) / 131072.0 }
            .distinctUntilChanged()
            .do(onNext: { result.mbpsTracked.append($0) })
            .publish()
        
        let rxMaxMbpsResults = rxMbpsResults
            .scan(0, accumulator: { max($0, $1) })
        
        let rxMbResults = rxBandwidthTest
            .map { Double($0.downloadProgress?.bytesWritten ?? 0) / 1048576.0 }
        
        let rxFinalResult = rxBandwidthTest
            .takeLast(1)
            .map { lastData -> BandwidthTestResult in
                result.finishTime = NSDate().timeIntervalSince1970
                result.mbDownloaded = Double(lastData.downloadProgress?.bytesWritten ?? 0) / 1048576.0
                result.location = lastData.location
                return result
            }
            .asSingle()
        
        return BandwidthTestEvents(onStart: Single.just(NSDate()),
                                   onFinish: rxFinalResult,
                                   onMbpsTracked: rxMbpsResults,
                                   onMaxMbpsTracked: rxMaxMbpsResults,
                                   onDownloadedMBTracked: rxMbResults,
                                   initializer:
            { [unowned rxMbpsResults, unowned rxBandwidthTest] in
                rxMbpsResults.connect().disposed(by: $0)
                rxBandwidthTest.connect().disposed(by: $0)
            }
        )
    }
}
