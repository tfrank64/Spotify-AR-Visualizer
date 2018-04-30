//
//  VectorExtension.swift
//  MusicAR
//
//  Created by Taylor Franklin on 4/30/18.
//  Copyright © 2018 Taylor Franklin. All rights reserved.
//

import Foundation
import ARKit

extension SCNVector3 {
    
    func distance(to destination: SCNVector3) -> CGFloat {
        let dx = destination.x - x
        let dy = destination.y - y
        let dz = destination.z - z
        
        let meters = sqrt(dx*dx + dy*dy + dz*dz)
        let inches: Float = 39.3701
        
        return CGFloat(meters * inches)
    }
}

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}
