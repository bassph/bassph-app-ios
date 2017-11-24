//
//  ReportMapViewController.swift
//  BASS
//
//  Created by Andrew on 02/05/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

class ReportMapViewController : UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Map"
        
        let webView = UIWebView()
        webView.loadRequest(URLRequest(url: URL(string: "https://bass.bnshosting.net/public")!))
        webView.scalesPageToFit = true
        view.addSubview(webView)
        
        webView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
}
