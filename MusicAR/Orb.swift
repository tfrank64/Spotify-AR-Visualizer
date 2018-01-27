import Foundation
import SceneKit
import ARKit

class Orb: SCNNode {
    
    var anchor :ARPlaneAnchor
    
    init(anchor: ARPlaneAnchor) {
        
        self.anchor = anchor
        super.init()
        setup()
    }
    
    private func setup() {
        
        let sphere = SCNSphere(radius: 0.1)
        
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
        
        sphereNode.position = SCNVector3(anchor.center.x, 0.2, anchor.center.z)
        
        let sphereEmitter = createSphericalEmission(color: UIColor.red, geometry: sphere)
        sphereNode.addParticleSystem(sphereEmitter)
        
        // add to the parent
        self.addChildNode(sphereNode)
    }
    
    func createSphericalEmission(color: UIColor, geometry: SCNGeometry) -> SCNParticleSystem {
        let colorSphere = SCNParticleSystem(named: "ambient.scnp", inDirectory: nil)!
        colorSphere.particleColor = color
        colorSphere.emitterShape = geometry
        return colorSphere
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

