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
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        let mbpsLabel = UILabel()
        let mbLabel = UILabel()
        view.addSubview(mbpsLabel)
        view.addSubview(mbLabel)
        
        mbpsLabel.text = "0.00 MB"
        mbLabel.text = "0 Mbps"
        
        mbpsLabel.snp.makeConstraints {
            $0.bottom.equalToSuperview()
            $0.width.equalTo(view.snp.width).dividedBy(2)
            $0.height.equalTo(60)
            $0.left.equalToSuperview()
        }
        
        mbLabel.snp.makeConstraints {
            $0.bottom.equalToSuperview()
            $0.width.equalTo(view.snp.width).dividedBy(2)
            $0.height.equalTo(60)
            $0.right.equalToSuperview()
        }
        
        BandwidthTestHandler.instance
            .onDownloadedMBUpdated
            .subscribe { [weak mbLabel] in
                let mb = $0.element ?? 0
                print("Downloaded:", mb, "MB")
                mbLabel?.text = String(format: "%.2f MB", mb)
            }
            .addDisposableTo(disposeBag)
        
        BandwidthTestHandler.instance
            .onMbpsTracked
            .subscribe { [weak mbpsLabel] in
                let mbps = $0.element ?? 0
                print("Tracked:", $0.element ?? 0, "Mbps")
                mbpsLabel?.text = String(format: "%.2f Mbps", mbps)
            }
            .addDisposableTo(disposeBag)
        
        BandwidthTestHandler.instance
            .status
            .subscribe { [weak startTestButton] in
                let status = $0.element ?? .idle
                print("Status:", status)
                startTestButton?.isEnabled = status == .idle
            }
            .addDisposableTo(disposeBag)
    }
    
    func onStartTestButtonClicked(button: UIButton) {
        button.isEnabled = false
        BandwidthTestHandler.instance.startTest()
    }
    
}

