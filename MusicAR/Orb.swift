import Foundation
import SceneKit
import ARKit
import AVFoundation

class Orb: SCNNode, AVAudioPlayerDelegate {
    
    var anchor: ARPlaneAnchor
    var orbParticleSystem: SCNParticleSystem!
    var audioPlayer: AVAudioPlayer!
    var audioTimer: Timer?
    var isPlaying = false
    var baseSoundPower: Float = 0
    var audioChanges: Float = 1
    
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
        
        let sphereEmitter = createSphericalEmission(color: UIColor.blue, geometry: sphere)
        sphereNode.addParticleSystem(sphereEmitter)
        
        // add to the parent
        self.addChildNode(sphereNode)
    }
    
    func createSphericalEmission(color: UIColor, geometry: SCNGeometry) -> SCNParticleSystem {
        self.orbParticleSystem = SCNParticleSystem(named: "ambient.scnp", inDirectory: nil)!
        self.orbParticleSystem.particleColor = color
        self.orbParticleSystem.emitterShape = geometry
        self.orbParticleSystem.birthRate = 0
        self.orbParticleSystem.particleSize = 0.05
        return self.orbParticleSystem
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginPlayingMusic() {
        if let audioFileURL = Bundle.main.url(forResource: "spiderManTheme", withExtension: "mp3") {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
                self.audioPlayer.isMeteringEnabled = true
                self.audioPlayer.delegate = self
                DispatchQueue.main.async {
                    if self.audioTimer == nil {
                        self.audioTimer = Timer.scheduledTimer(timeInterval: 0.5,
                                                               target: self,
                                                               selector: #selector(self.monitorAudioPlayer),
                                                               userInfo: nil,
                                                               repeats: true)
                    }
                    self.playPauseMusic()
                }
            } catch {
                print("Cannot init audio player: \(error.localizedDescription)")
            }
        }
    }
    
    func playPauseMusic() {
        if self.isPlaying {
            self.audioPlayer.pause()
        } else {
            self.audioPlayer.play()
        }
        self.isPlaying = !self.isPlaying
        print("isplaying?? \(self.isPlaying)")
    }
    
    @objc func monitorAudioPlayer() {
        self.audioPlayer.updateMeters()
        guard self.audioPlayer.numberOfChannels > 0 else { return }
        let peakPower = self.audioPlayer.peakPower(forChannel: 0)
        print("Peak: \(peakPower)")

        if self.audioChanges <= 5 {
            self.baseSoundPower = self.baseSoundPower + peakPower
            if self.audioChanges == 5 {
                self.baseSoundPower = self.baseSoundPower / self.audioChanges
            }
//            print("BasePow: \(self.baseSoundPower) with changes: \(self.audioChanges)")
            self.audioChanges += 1
            return
        }
        let valueInRange = (peakPower - self.baseSoundPower)/(0 - self.baseSoundPower)
        let birthRate = valueInRange * 300 //(x - start)/(end - start)
        print("birthrate: \(birthRate)")
        self.orbParticleSystem.birthRate = CGFloat(birthRate)
        print("valueInrange: \(valueInRange)")
        let particleVelocity = valueInRange * 3
        print("velocity: \(particleVelocity)")
        self.orbParticleSystem.particleVelocity = CGFloat(particleVelocity)
        let particleSize = valueInRange * 0.5
        print("size: \(particleSize)")
        self.orbParticleSystem.particleSize = CGFloat(particleSize)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.audioTimer != nil else { return }
        self.audioTimer?.invalidate()
        self.audioTimer = nil
    }
}

