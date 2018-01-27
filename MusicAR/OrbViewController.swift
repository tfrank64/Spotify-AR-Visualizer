import UIKit
import SceneKit
import ARKit
// place on center horizontal plane,make the size of ottoman.
// add particle emission in different colors and intensities
// clean up, fix force unwrapping
class OrbViewController: UIViewController, ARSCNViewDelegate {
    
    var sceneView: ARSCNView!
    var orb: Orb?
    var planes = [OverlayPlane]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(self.sceneView)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints,ARSCNDebugOptions.showWorldOrigin]
        
        let scene = SCNScene()
        sceneView.scene = scene
        insertLighting(position: SCNVector3(1.0,2.0,-1))
    }
    
    private func insertLighting(position: SCNVector3) {
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        
        let directionalNode = SCNNode()
        directionalNode.name = "DirectionalNode"
        directionalNode.light = directionalLight
        directionalNode.position = position
        
        directionalNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(-90), 0, GLKMathDegreesToRadians(-45))
        self.sceneView.scene.rootNode.addChildNode(directionalNode)
    }
    
    // MARK: ARSCNViewDelegate methods
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let estimate: ARLightEstimate? = sceneView.session.currentFrame?.lightEstimate
        if estimate == nil {
            return
        }
        let directionalNode = self.sceneView.scene.rootNode.childNode(withName: "DirectionalNode", recursively: true)
        directionalNode?.light?.intensity = (estimate?.ambientIntensity)!
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if !(anchor is ARPlaneAnchor) {
            return
        }
        
        if let arAnchor = anchor as? ARPlaneAnchor {
            if self.orb == nil {
                self.orb = Orb(anchor: arAnchor)
                node.addChildNode(self.orb!)
            }
            
            let plane = OverlayPlane(anchor: arAnchor)
            self.planes.append(plane)
            node.addChildNode(plane)
        }
        

    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        let plane = self.planes.filter { plane in
            return plane.anchor.identifier == anchor.identifier
        }.first
        
        if plane == nil {
            return
        }
        
        plane?.update(anchor: anchor as! ARPlaneAnchor)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
}

