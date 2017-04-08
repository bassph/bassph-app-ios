//
//  BandwidthTestHandler.swift
//  BASS
//
//  Created by Andrew on 08/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import RxSwift
import RxAlamofire

class BandwidthTestHandler {
    
    enum Status {
        case idle
        case testing
        case testError
        case uploading
        case uploadError
        case completed
    }
    
    var dataCapSizeInMB: Int = 5
    var testLengthInSeconds: TimeInterval = 10
    let samplingRateInSeconds: TimeInterval = 1
    let speedTestUrl = "http://speedtest.singapore.linode.com/100MB-singapore.bin"
    
    private let disposeBag = DisposeBag()
    private let tracker = BytesTracker()
    private var downloadDisposable: Disposable? = nil
    private var lastTrackerBytesReceived: UInt64 = 0
    private var downloadFailed = false
    private var dataCapSizeReached = false
    private var testLengthFinished = false
    
    var megaBytesDownloaded = BehaviorSubject<Double>(value: 0)
    var mbpsTracked = ReplaySubject<Double>.createUnbounded()
    var status = BehaviorSubject<Status>(value: .idle)
    
    func startTest() {
        do {
            if try status.value() == .idle {
                downloadFailed = false
                dataCapSizeReached = false
                testLengthFinished = false
                run()
            }
        } catch {
            
        }
    }
    
    private func run() {
        status.onNext(.testing)
        
        print(NetworkHandler.getCellSignalStrength())
        print(NetworkHandler.getRadioAccessTechnology())
        NetworkHandler.printCarrier()
        
        downloadDisposable = RxAlamofire
            .request(.get, speedTestUrl)
            .flatMap { request -> Observable<RxProgress> in
                return request.rx.progress()
            }
            .observeOn(MainScheduler.instance)
            .skip(1)
            .do(onNext: { [weak self] in
                let cap = Int64((self?.dataCapSizeInMB ?? 0) * 1048576)
                if cap > 0 && $0.bytesWritten > cap {
                    self?.dataCapSizeReached = true
                    self?.megaBytesDownloaded.onNext(Double($0.bytesWritten) / 1048576)
                    self?.downloadDisposable?.dispose()
                }
            }, onError: { [weak self] (error) in
                self?.downloadFailed = true
            })
            .throttle(1, scheduler: MainScheduler.instance)
            .subscribe { [weak self] in
                self?.megaBytesDownloaded.onNext(Double($0.element?.bytesWritten ?? 0) / 1048576)
            }
        
        lastTrackerBytesReceived = 0
        tracker.track(seconds: 20)
            .skip(1)
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
                    me.mbpsTracked.onNext(mbps)
                    me.lastTrackerBytesReceived = current
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
    
    private func uploadResult() {
        status.onNext(.uploading)
        
        let url = ""
        RxAlamofire
            .requestJSON(.post, url)
            .subscribe(onNext: { [weak self] (response, json) in
                
            }, onError: { [weak self] (error) in
                self?.status.onNext(.uploadError)
                self?.status.onNext(.idle)
            }, onCompleted: { [weak self] in
                self?.status.onNext(.completed)
                self?.status.onNext(.idle)
            })
            .addDisposableTo(disposeBag)
    }
    
}
