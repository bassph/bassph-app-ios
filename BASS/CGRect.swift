//
//  CGRec.swift
//  BASS
//
//  Created by Andrew on 12/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit

extension CGRect {
    
    var center: CGPoint {
        let x = self.midX
        let y = self.midY
        return CGPoint(x: x, y: y)
    }
    
}
