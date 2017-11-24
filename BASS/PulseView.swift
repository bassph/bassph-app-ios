//
//  PulseView.swift
//  BASS
//
//  Created by Andrew on 12/04/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import UIKit

class PulseView : UIView {
    
    convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    convenience init(origin: CGPoint) {
        self.init(frame: CGRect.zero)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    func pulse(point: CGPoint, size: CGFloat) {
        let view = createCircle(originPoint: point)
        self.addSubview(view)
        
        UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut, animations: {
            view.frame.origin = CGPoint(x: point.x - size * 0.5, y: point.y - size * 0.5)
            view.frame.size = CGSize(width: size, height: size)
            view.layer.cornerRadius = size * 0.5
            view.backgroundColor = UIColor.white
        }) { (finished) in
            view.removeFromSuperview()
        }
    }
    
    private func createCircle(originPoint: CGPoint) -> UIView {
        let view = UIView(frame: CGRect(origin: originPoint, size: CGSize(width: 0, height: 0)))
        view.backgroundColor = UIColor(rgb: 0x009cff)
        return view
    }
    
    func setupView() {
        
    }
    
}
