//
//  ViewController.swift
//  BASS
//
//  Created by Andrew Alegre on 23/09/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

class SplashViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        /*
        for info in NetworkInterfaceHandler.getAllNetworkInterfaceInfo() {
            print("\(info.name) R: \(info.bytesReceived) S: \(info.bytesSent)")
        }
         */
        
        self.view.backgroundColor = .darkGray
        
        _ = view.add(UIView()) {
            //
            $0.constraint {
                $0.height.equalTo(128 + 64 + 16)
                $0.width.equalToSuperview()
                $0.centerY.equalToSuperview()
            }
            
            //
            let imageViewLogo = $0.add(UIImageView()) {
                $0.backgroundColor = .black
                $0.constraint {
                    $0.top.equalToSuperview()
                    $0.width.equalTo(128)
                    $0.height.equalTo(128)
                    $0.centerX.equalToSuperview()
                }
            }
            
            // indicator
            _ = $0.add(UIActivityIndicatorView()) {
                $0.activityIndicatorViewStyle = .whiteLarge
                $0.startAnimating()
                $0.constraint {
                    $0.top.equalTo(imageViewLogo.snp.bottom).offset(16)
                    $0.width.equalTo(64)
                    $0.height.equalTo(64)
                    $0.centerX.equalToSuperview()
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }

}

