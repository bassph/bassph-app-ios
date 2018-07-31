//
//  ViewController.swift
//  BASS
//
//  Created by Andrew Alegre on 04/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import FBSDKShareKit

class MainViewController: UIViewController {
    
    let maxMbpsLabel = UILabel()
    let maxMBLabel = UILabel()
    let mbpsLabel = UILabel()
    let mbLabel = UILabel()
    
    let pulseView = PulseView()
    let signalImageView = UIImageView()
    let activityIndicator = UIActivityIndicatorView()
    let disposeBag = DisposeBag()
    
    var moodView: UIView!
    var currentMood: Int = 0
    var lastMappedResult: [String : Any]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "BASS PH"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Map", style: .plain, target: self, action: #selector(onNavBarRightButtonClicked))
        
        view.addSubview(pulseView)
        pulseView.snp.makeConstraints {
            $0.width.equalToSuperview()
            $0.height.equalToSuperview()
            $0.left.equalToSuperview()
            $0.top.equalToSuperview()
        }
        
        let buttonBackgroundView = UIView()
        let startTestButton = UIButton()
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
        
        maxMBLabel.text = String(format: "%.2f MB", 0)
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
        
        // Mood
        _ = view.add(UIView()) {
            $0.isHidden = true
            $0.backgroundColor = UIColor(red: 0, green: 0, blue: 0, a: 180)
            $0.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            _ = $0.add(UIView()) { (dialog) in
                dialog.backgroundColor = UIColor.white
                dialog.layer.cornerRadius = 6
                dialog.snp.makeConstraints {
                    $0.centerY.equalToSuperview()
                    $0.left.equalToSuperview().offset(6)
                    $0.width.equalToSuperview().inset(6)
                    $0.height.equalTo(206)
                }
                
                let label = dialog.add(UILabel()) { (label) in
                    label.numberOfLines = 2
                    label.text = "How feel about your current internet provider?"
                    label.lineBreakMode = .byWordWrapping
                    label.textAlignment = .center
                    label.snp.makeConstraints {
                        $0.left.equalToSuperview().offset(12)
                        $0.width.equalToSuperview().inset(12)
                        $0.height.equalTo(60)
                        $0.top.equalToSuperview().offset(12)
                    }
                }
                
                var iconViews = [UIImageView]()
                for i in stride(from: 0, to: 5, by: 1) {
                    _ = dialog.add(UIImageView()) { (icon) in
                        iconViews.append(icon)
                        icon.isUserInteractionEnabled = true
                        if currentMood + 2 == i {
                            icon.image = UIImage(named: "Mood\(i)")
                        } else {
                            icon.image = UIImage(named: "MoodN\(i)")
                        }
                        icon.tag = i
                        icon.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onMoodIconTapped)))
                        icon.snp.makeConstraints {
                            if i > 0 {
                                $0.left.equalTo(label.snp.right).multipliedBy(Double(i) * 0.2).offset(12)
                            } else {
                                $0.left.equalToSuperview().offset(12)
                            }
                            $0.top.equalTo(label.snp.bottom)
                            $0.width.equalToSuperview().dividedBy(5).offset(-12)
                            $0.height.equalTo(dialog.snp.width).dividedBy(5).offset(-12)
                        }
                    }
                }
                
                _ = dialog.add(UIButton()) { (button) in
                    button.addTarget(self, action: #selector(onMoodSubmitClicked), for: .touchUpInside)
                    button.setTitle("Submit", for: .normal)
                    button.setTitleColor(UIColor.white, for: .normal)
                    button.backgroundColor = UIColor(rgb: 0x009cff)
                    button.snp.makeConstraints {
                        $0.top.equalTo(iconViews[0].snp.bottom).offset(12)
                        $0.centerX.equalToSuperview()
                        $0.width.equalTo(140)
                        $0.height.equalTo(48)
                    }
                }
            }
        }
        
        
        
    }
    
    @objc func onMoodSubmitClicked() {
        moodView.isHidden = true
        self.onMoodAcquired()
    }
    
    @objc func onMoodIconTapped(sender: UITapGestureRecognizer) {
        if let view = sender.view as? UIImageView {
            for subview in view.superview!.subviews
            {
                if let item = subview as? UIImageView
                {
                    item.image = UIImage(named: "MoodN\(item.tag)")
                }
            }
            view.image = UIImage(named: "Mood\(view.tag)")
            self.currentMood = view.tag - 2
        }
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
    
    @objc func onStartTestButtonClicked(button: UIButton) {
        let parameters = BandwidthTestParameters()
        let testEvents = BandwidthTestHandler.prepareObserving(with: parameters)
        
        self.maxMBLabel.text = String(format: "%.2f MB", parameters.downloadCapSizeInMB)
        
        testEvents
            .onStart
            .subscribe { [unowned self, unowned button] (_) in
                button.isHidden = true
                self.activityIndicator.startAnimating()
            }
            .disposed(by: disposeBag)
        
        testEvents
            .onFinish
            .subscribe { [unowned self, unowned button] in
                button.isHidden = false
                self.activityIndicator.stopAnimating()
                
                switch $0 {
                case .success(let result):
                    self.onTestFinished(result)
                    break
                case .error(let error):
                    self.onTestFailed(error)
                    break
                }
            }
            .disposed(by: disposeBag)
        
        testEvents
            .onMbpsTracked
            .subscribe { [unowned self] in
                if let mbps = $0.element {
                    self.mbpsLabel.text = String(format: "%.2f Mbps", mbps)
                    // start pulse
                    let point = self.signalImageView.frame.center
                    self.pulseView.pulse(point: point, size: self.view.frame.height * 1.2)
                }
            }
            .disposed(by: disposeBag)
        
        testEvents
            .onMaxMbpsTracked
            .subscribe { [unowned self] in
                if let mbps = $0.element {
                    self.maxMbpsLabel.text = String(format: "%.2f Mbps", mbps)
                }
            }
            .disposed(by: disposeBag)
        
        testEvents
            .onDownloadedMBTracked
            .subscribe { [unowned self] in
                if let mbps = $0.element {
                    self.mbLabel.text = String(format: "%.2f MB", mbps)
                }
            }
            .disposed(by: disposeBag)
        
        testEvents.begin(with: disposeBag)
    }
    
    @objc func onNavBarRightButtonClicked(button: UIBarButtonItem) {
        self.navigationController?.pushViewController(ReportMapViewController(), animated: true)
    }
    
    var currentResult: BandwidthTestResult!
    
    func onTestFinished(_ result: BandwidthTestResult) {
        self.currentResult = result
        self.moodView.isHidden = false
    }
    
    func onMoodAcquired() {
        onUploadResult(self.currentResult, self.currentMood)
    }
    
    func onUploadResult(_ result: BandwidthTestResult, _ mood: Int) {
        let generated = ResultHandler.generateMapped(with: result, andMood: mood)
        JustHUD.shared.showInView(view: self.view, withHeader: "Uploading Results", andFooter: "Please wait...")
        ResultHandler
            .uploadMappedResult(generated)
            .subscribe { [unowned self] in
                JustHUD.shared.hide()
                switch $0 {
                case .success(let mappedResult):
                    self.lastMappedResult = mappedResult
                    
                    var signal = mappedResult["signal"] as? String ?? "None"
                    if signal == "" { signal = "None" }
                    self.showResultDialog(title: "Test Results", message: "" +
                        "Connectivity: \((mappedResult["connectivity"] as! [String : Any])["typeName"]!)\n" +
                        "Bandwidth: \(mappedResult["bandwidth"]!)\n" +
                        "Carrier Name: \(mappedResult["operator"]!)\n" +
                        "Radio Access: \(signal)\n" +
                        "Signal Strength: \(mappedResult["signalBars"]!)/5\n\n" +
                        "Thank you!")
                    break
                case .error(_):
                    
                    self.showAlertDialog(title: "Upload Error", message: "Something went wrong with the result upload. Please try again.\n(If the errors persist, please report to our Facebook page and we'll fix it ASAP.)")
                    
                    break
                }
            }
            .disposed(by: disposeBag)
    }
    
    func onTestFailed(_ error: Error) {
        let code = (error as NSError).code
        print("Error code: \(code)")
        self.showAlertDialog(title: "Testing Error", message: "Something went wrong with the test. Please try again.\n(If the errors persist, please report to our Facebook page and we'll fix it ASAP.)")
    }
    
    func onShareToFacebook() {
        /*
        let result = BandwidthTestHandler.instance.lastResult
        var signal = result["signal"] as? String ?? "None"
        if signal == "" { signal = "None" }
        
        let share = FBSDKShareLinkContent()
        let data = "" +
            "Connectivity: \((result["connectivity"] as! [String : Any])["typeName"]!) |" +
            "Bandwidth: \(result["bandwidth"]!) |" +
            "Carrier Name: \(result["operator"]!) |" +
            "Radio Access: \(signal) |" +
            "Signal Strength: \(result["signalBars"]!)/5"
        share.contentURL = URL(string: "https://bass.bnshosting.net/device?data=" + data.toBase64())
        
        
        share.imageURL = URL(string: "https://scontent.fmnl4-6.fna.fbcdn.net/v/t1.0-9/17796714_184477785394716_1700205285852495439_n.png?oh=40acf149ffe8dcc0e24e60af7f844514&oe=595D6465")
 
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
         */
    }
    
    func showResultDialog(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler: nil))
        /*alert.addAction(UIAlertAction(title: "Share to FB", style: UIAlertActionStyle.default, handler: { [weak self] (alert) in
            self?.onShareToFacebook()
        }))*/
        alert.addAction(UIAlertAction(title: "Raw Data", style: UIAlertActionStyle.default, handler: { [unowned self] (alert) in
            //let result = BandwidthTestHandler.instance.lastResult
            self.showAlertDialog(title: "Raw Data", message: self.lastMappedResult?.debugDescription ?? "(Error)")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func showAlertDialog(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
}

