//
//  AppDelegate.swift
//  BASS
//
//  Created by Andrew on 04/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import UIKit
import RxSwift
import RxAlamofire

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        
    }

}

extension UIViewController {
    
    var app: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    
}

