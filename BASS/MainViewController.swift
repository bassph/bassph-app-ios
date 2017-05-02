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
import FBSDKShareKit

class MainViewController: UIViewController {
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "BASS PH"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Map", style: .plain, target: self, action: #selector(onNavBarRightButtonClicked))
        
        let pulseView = PulseView()
        view.addSubview(pulseView)
        pulseView.snp.makeConstraints {
            $0.width.equalToSuperview()
            $0.height.equalToSuperview()
            $0.left.equalToSuperview()
            $0.top.equalToSuperview()
        }
        
        let buttonBackgroundView = UIView()
        let startTestButton = UIButton()
        let signalImageView = UIImageView()
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.activityIndicatorViewStyle = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.stopAnimating()
        
        signalImageView.image = #imageLiteral(resourceName: "Signal")
        view.addSubview(buttonBackgroundView)
        view.addSubview(signalImageView)
        view.addSubview(startTestButton)
        view.addSubview(activityIndicator)
        
        buttonBackgroundView.backgroundColor = UIColor(rgb: 0x009cff)
        buttonBackgroundView.layer.cornerRadius = 6.0
        buttonBackgroundView.clipsToBounds = true
        
        startTestButton.tintColor = UIColor.white
        startTestButton.setTitle("Begin Test", for: .normal)
        startTestButton.setTitleColor(UIColor.white, for: .normal)
        startTestButton.setTitleColor(UIColor(rgb: 0x00cfff), for: .highlighted)
        startTestButton.addTarget(self, action: #selector(onStartTestButtonClicked), for: .touchUpInside)
        
        buttonBackgroundView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalTo(160)
            $0.height.equalTo(60)
        }
        
        startTestButton.snp.makeConstraints {
            $0.center.equalTo(buttonBackgroundView)
            $0.width.equalTo(buttonBackgroundView)
            $0.height.equalTo(buttonBackgroundView)
        }
        
        signalImageView.snp.makeConstraints {
            $0.bottom.equalTo(startTestButton.snp.top).offset(8)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(100)
            $0.height.equalTo(100)
        }
        
        activityIndicator.snp.makeConstraints {
            $0.center.equalTo(startTestButton)
        }
        
        let maxMbpsLabel = UILabel()
        let maxMBLabel = UILabel()
        let mbpsLabel = UILabel()
        let mbLabel = UILabel()
        
        view.addSubview(mbpsLabel)
        view.addSubview(mbLabel)
        view.addSubview(maxMbpsLabel)
        view.addSubview(maxMBLabel)
        
        mbpsLabel.text = "0 Mbps"
        mbpsLabel.textAlignment = .center
        mbpsLabel.textColor = UIColor(rgb: 0x009cff)
        
        mbLabel.text = "0.00 MB"
        mbLabel.textAlignment = .center
        mbLabel.textColor = UIColor(rgb: 0x009cff)
        
        maxMbpsLabel.text = "0 Mbps"
        maxMbpsLabel.font = UIFont.boldSystemFont(ofSize: maxMbpsLabel.font.pointSize)
        maxMbpsLabel.textAlignment = .center
        maxMbpsLabel.textColor = UIColor(rgb: 0x009cff)
        
        maxMBLabel.text = String(format: "%.2f MB", Float(BandwidthTestHandler.instance.dataCapSizeInMB))
        maxMBLabel.font = UIFont.boldSystemFont(ofSize: maxMBLabel.font.pointSize)
        maxMBLabel.textAlignment = .center
        maxMBLabel.textColor = UIColor(rgb: 0x009cff)
        
        maxMbpsLabel.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(16)
            $0.width.equalTo(view.snp.width).dividedBy(2)
            $0.height.equalTo(30)
            $0.left.equalToSuperview()
        }
        
        maxMBLabel.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(16)
            $0.width.equalTo(view.snp.width).dividedBy(2)
            $0.height.equalTo(30)
            $0.right.equalToSuperview()
        }
        
        mbpsLabel.snp.makeConstraints {
            $0.bottom.equalTo(maxMbpsLabel.snp.top)
            $0.width.equalTo(view.snp.width).dividedBy(2)
            $0.height.equalTo(30)
            $0.left.equalToSuperview()
        }
        
        mbLabel.snp.makeConstraints {
            $0.bottom.equalTo(maxMBLabel.snp.top)
            $0.width.equalTo(view.snp.width).dividedBy(2)
            $0.height.equalTo(30)
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
            .subscribe { [weak self, weak signalImageView, weak mbpsLabel, weak maxMbpsLabel] in
                
                let point = (signalImageView?.frame.center)!
                pulseView.pulse(point: point, size: (self?.view.frame.height)! * 1.2)
                
                let mbps = $0.element ?? 0
                let max = BandwidthTestHandler.instance.maxMbps
                print("Tracked:", $0.element ?? 0, "Mbps")
                mbpsLabel?.text = String(format: "%.2f Mbps", mbps)
                maxMbpsLabel?.text = String(format: "%.2f Mbps", max)
            }
            .addDisposableTo(disposeBag)
        
        BandwidthTestHandler.instance
            .status
            .subscribe { [weak self, weak startTestButton, weak activityIndicator, weak signalImageView] in
                let status = $0.element ?? .idle
                print("Status:", status)
                startTestButton?.isEnabled = status == .idle
                startTestButton?.isHidden = status != .idle
                signalImageView?.isHidden = status == .idle
                
                if status != .idle {
                    activityIndicator?.startAnimating()
                } else {
                    activityIndicator?.stopAnimating()
                }
                
                if status == .completed {
                    let result = BandwidthTestHandler.instance.lastResult
                    var signal = result["signal"] as? String ?? "None"
                    if signal == "" { signal = "None" }
                    self?.showResultDialog(title: "Test Results", message: "" +
                        "Connectivity: \((result["connectivity"] as! [String : Any])["typeName"]!)\n" +
                        "Bandwidth: \(result["bandwidth"]!)\n" +
                        "Carrier Name: \(result["operator"]!)\n" +
                        "Radio Access: \(signal)\n" +
                        "Signal Strength: \(result["signalBars"]!)/5\n\n" +
                        "Thank you!")
                }
                
                if status == BandwidthTestHandler.Status.testError {
                    self?.showAlertDialog(title: "Testing Error", message: "Something went wrong with the test. Please try again.\n" +
                        "(If the errors persist, please report to our Facebook page and we'll fix it ASAP.)")
                }
                if status == BandwidthTestHandler.Status.uploadError {
                    self?.showAlertDialog(title: "Upload Error", message: "Something went wrong with the result upload. Please try again.\n" +
                        "(If the errors persist, please report to our Facebook page and we'll fix it ASAP.)")
                }
            }
            .addDisposableTo(disposeBag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let defaults = UserDefaults.standard
        let messageShown = defaults.bool(forKey: "startingMessage0")
        if !messageShown {
            showAlertDialog(title: "BASS PH", message: "Thank you for joining the movement!\n\nBASS PH is " +
                "by-volunteers, for-volunteers crowdsourcing app that aims to improve the Philippine " +
                "internet connectivity by providing actionable data for everyone.\n\n" +
                "Please send in your comments, suggestions, help, and support through our Facebook page, as we " +
                "are also still currently improving our apps, data analysis, and collection methods.\n\n" +
                "Thanks again and more power to all of us!\n\n" +
                "- BASS PH Team")
            defaults.set(true, forKey: "startingMessage0")
        }
    }
    
    func onStartTestButtonClicked(button: UIButton) {
        button.isEnabled = false
        BandwidthTestHandler.instance.startTest()
    }
    
    func onNavBarRightButtonClicked(button: UIBarButtonItem) {
        self.navigationController?.pushViewController(ReportMapViewController(), animated: true)
    }
    
    func onShareToFacebook() {
        let result = BandwidthTestHandler.instance.lastResult
        var signal = result["signal"] as? String ?? "None"
        if signal == "" { signal = "None" }
        
        let share = FBSDKShareLinkContent()
        share.imageURL = URL(string: "https://scontent.fmnl4-6.fna.fbcdn.net/v/t1.0-9/17796714_184477785394716_1700205285852495439_n.png?oh=40acf149ffe8dcc0e24e60af7f844514&oe=595D6465")
        share.contentURL = URL(string: "https://bass.bnshosting.net/device")
        share.contentDescription = "" +
            "Connectivity: \((result["connectivity"] as! [String : Any])["typeName"]!) :" +
            "Bandwidth: \(result["bandwidth"]!) :" +
            "Carrier Name: \(result["operator"]!) :" +
            "Radio Access: \(signal) :" +
            "Signal Strength: \(result["signalBars"]!)/5"
        share.hashtag = FBSDKHashtag(string: "#BASSparaSaBayan")
        
        let dialog = FBSDKShareDialog()
        dialog.mode = .feedWeb
        dialog.fromViewController = self
        dialog.shareContent = share
        
        if (dialog.canShow()) {
            dialog.show()
        } else {
            dialog.mode = .feedBrowser
            dialog.show()
        }
    }
    
    func showResultDialog(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Share to FB", style: UIAlertActionStyle.default, handler: { [weak self] (alert) in
            self?.onShareToFacebook()
        }))
        alert.addAction(UIAlertAction(title: "Raw Data", style: UIAlertActionStyle.default, handler: { [weak self] (alert) in
            let result = BandwidthTestHandler.instance.lastResult
            self?.showAlertDialog(title: "Raw Data", message: result.debugDescription)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func showAlertDialog(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
}

