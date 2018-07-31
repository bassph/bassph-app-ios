//
//  UIViewController.swift
//  BASS
//
//  Created by Andrew Alegre on 02/10/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    
    var app: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    
}
