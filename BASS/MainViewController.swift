//
//  ViewController.swift
//  BASS
//
//  Created by Andrew on 04/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

class MainViewController: UIViewController {
    
    let bandwidthTestHandler = BandwidthTestHandler()
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bandwidthTestHandler.megaBytesDownloaded
            .subscribe { print("Downloaded:", $0.element ?? 0, "MB") }
            .addDisposableTo(disposeBag)
        
        bandwidthTestHandler.mbpsTracked
            .subscribe { print("Tracked:", $0.element ?? 0, "mbps") }
            .addDisposableTo(disposeBag)
        
        bandwidthTestHandler.status
            .subscribe { print("Status:", $0.element ?? .idle) }
            .addDisposableTo(disposeBag)
        
        let startTestButton = UIButton()
        view.addSubview(startTestButton)
        
        startTestButton.backgroundColor = UIColor.black
        startTestButton.setTitle("Start Test", for: .normal)
        startTestButton.addTarget(self, action: #selector(onStartTestButtonClicked), for: .touchUpInside)
        startTestButton.snp.makeConstraints {
            $0.center.equalTo(view.snp.center)
            $0.width.equalTo(200)
            $0.height.equalTo(60)
        }
    }
    
    func onStartTestButtonClicked(button: UIButton) {
        button.isEnabled = false
        bandwidthTestHandler.startTest()
        
    }
    
}

