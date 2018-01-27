
import Foundation
import SceneKit
import ARKit

class Orb : SCNNode {
    
    var anchor :ARPlaneAnchor
//    var planeGeometry :SCNPlane!
    
    init(anchor :ARPlaneAnchor) {
        
        self.anchor = anchor
        super.init()
        setup()
    }
    
//    func update(anchor: ARPlaneAnchor) {
//
//        self.planeGeometry.width = CGFloat(anchor.extent.x);
//        self.planeGeometry.height = CGFloat(anchor.extent.z);
//        self.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z);
//
//        let planeNode = self.childNodes.first!
//
//        planeNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: self.planeGeometry, options: [:]))
//    }
    
    private func setup() {
        
        let sphere = SCNSphere(radius: 0.2)
        
        let sphereNode = SCNNode()
        sphereNode.geometry = sphere
        
        let sphereMaterial = SCNMaterial()
        sphereMaterial.lightingModel = SCNMaterial.LightingModel.physicallyBased
        let materialFilePrefix = "greasy-pan-2"
        sphereMaterial.diffuse.contents = UIImage(named: "\(materialFilePrefix)-albedo.png")
        sphereMaterial.roughness.contents = UIImage(named: "\(materialFilePrefix)-roughness.png")
        sphereMaterial.metalness.contents = UIImage(named: "\(materialFilePrefix)-metal.png")
        sphereMaterial.normal.contents = UIImage(named: "\(materialFilePrefix)-normal.png")
        sphereNode.geometry?.materials = [sphereMaterial]
        sphereNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 5, y: 1, z: 1, duration: 30)))
        
        print("anchor -> \(anchor)")
        sphereNode.position = SCNVector3(anchor.center.x, 0.2, anchor.center.z)
        
        // add to the parent
        self.addChildNode(sphereNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

