//
//  BandwidthTestResult.swift
//  BASS
//
//  Created by Andrew Alegre on 04/10/2017.
//  Copyright © 2017 Collave. All rights reserved.
//

import Foundation
import CoreLocation
import RxAlamofire

struct BandwidthTestData {
    var downloadProgress: RxProgress?
    var trackedData: BytesTrackerData?
    var location: CLLocation?
}
