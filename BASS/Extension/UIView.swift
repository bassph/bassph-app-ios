//
//  UIView.swift
//  BASS
//
//  Created by Andrew Alegre on 23/09/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

extension UIView {
    
    func addSubview<T: UIView>(_ view: T, block: (T)->Void) {
        self.addSubview(view)
        block(view)
    }
    
    func add<T: UIView>(_ view: T, block: (T)->Void) -> T {
        self.addSubview(view)
        block(view)
        return view
    }
    
    func add<T: UIView>(_ view: T) -> T {
        self.addSubview(view)
        return view
    }
    
    func constraint(closure: (ConstraintMaker)->Void) {
        self.snp.makeConstraints(closure)
    }
    
    var viewController: UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let responder = responder as? UIViewController {
                return responder
            }
            responder = responder?.next
        }
        return nil
    }
    
}
