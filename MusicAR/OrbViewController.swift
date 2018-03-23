import UIKit
import SceneKit
import ARKit

// have environment sound pickup option
// Have user pick color or "party mode". they pick song and go.
// tap orb to play/pause, swipe to skip
// Have sound increase/decrease based on orb proximity
class OrbViewController: UIViewController, ARSCNViewDelegate {
    
    var sceneView: ARSCNView!
    var orb: Orb?
    var spotifyPlaylistURI: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(self.sceneView)
        
        let backButton =  UIButton(frame: CGRect(x: -10, y: 10, width: 100, height: 44))
        backButton.titleLabel?.textColor = UIColor.white
        backButton.setTitle("Back", for: UIControlState.normal)
        backButton.addTarget(self, action: #selector(dismissARView), for: .touchUpInside)
        self.sceneView.addSubview(backButton)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
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
        guard let estimate = sceneView.session.currentFrame?.lightEstimate,
              let directionalNode = self.sceneView.scene.rootNode.childNode(withName: "DirectionalNode", recursively: true) else {
            return
        }
        directionalNode.light?.intensity = estimate.ambientIntensity
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let arAnchor = anchor as? ARPlaneAnchor {
            if self.orb == nil, let spotifyPlaylistURI = self.spotifyPlaylistURI {
                self.orb = Orb(anchor: arAnchor, spotifyPlaylistURI: spotifyPlaylistURI)
                node.addChildNode(self.orb!)
                self.sceneView.debugOptions = []
            }
        }
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
    
    @objc func dismissARView() {
        if let createdOrb = self.orb {
            createdOrb.cleanup(callback: { errorString in
                if let message = errorString {
                    print(message)
                }
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            })
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
