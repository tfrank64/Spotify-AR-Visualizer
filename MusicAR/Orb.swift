import Foundation
import SceneKit
import ARKit
import AVFoundation
import Accelerate

class Orb: SCNNode, AVAudioPlayerDelegate {
    
    var anchor: ARPlaneAnchor
    var playableUri: String
    
    var orbParticleSystem: SCNParticleSystem!
    var player: SPTAudioStreamingController?
    var cleanupCallback: ((String?) -> Void)?
    let audioEngine = AVAudioEngine()
    let minPowerLevel: Float = -63
    var maxPowerLevel: Float = -50
    var channel0Power: Float = -63
    
    init(anchor: ARPlaneAnchor, spotifyPlaylistURI: String) {
        self.anchor = anchor
        self.playableUri = spotifyPlaylistURI
        super.init()
        setup()
        initializePlayer()
    }
    
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
        
        sphereNode.position = SCNVector3(anchor.center.x, 0.2, anchor.center.z)
        
        let sphereEmitter = createSphericalEmission(color: UIColor.blue, geometry: sphere)
        sphereNode.addParticleSystem(sphereEmitter)
        
        // add to the parent
        self.addChildNode(sphereNode)
    }
    
    func createSphericalEmission(color: UIColor, geometry: SCNGeometry) -> SCNParticleSystem {
        guard let particleSystem = SCNParticleSystem(named: "ambient.scnp", inDirectory: nil) else {
            fatalError("Couldn't init particle system, app depends on this")
        }
        self.orbParticleSystem = particleSystem
        self.orbParticleSystem.particleColor = color
        self.orbParticleSystem.emitterShape = geometry
        self.orbParticleSystem.birthRate = 0
        self.orbParticleSystem.particleSize = 0.05
        return self.orbParticleSystem
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Music playing/analysis methods
    
    func initializePlayer() {
        if self.player == nil, let auth = SPTAuth.defaultInstance(), let authSession = SPTSession.getStoredSession() {
            self.player = SPTAudioStreamingController.sharedInstance()
            self.player!.playbackDelegate = self
            self.player!.delegate = self
            do {
                try player!.start(withClientId: auth.clientID)
                self.player!.login(withAccessToken: authSession.accessToken)
            } catch {
                print("Error starting player: \(error)")
            }
        }
    }
    
    func playOrPause() {
        self.player!.setIsPlaying(!self.player!.playbackState.isPlaying, callback: nil)
    }
    
    func nextTrack() {
        self.player!.skipNext(nil)
    }
    
    func backTrack() {
        self.player!.skipPrevious(nil)
    }
    
    func adjustVolumeLevel(level: CGFloat) {
        
        let volumeInRange = ((level * 0.01) - 0) / (2 - 0)
        self.player!.setVolume(SPTVolume(1 - volumeInRange)) { volError in
            if volError != nil {
                print("Error adjusting volume: \(String(describing: volError))")
            }
        }
    }
    
    func cleanup(callback: @escaping (String?) -> Void) {
        self.cleanupCallback = callback
        self.audioEngine.stop()
        if let player = self.player {
            player.logout()
        }
    }
}

extension Orb: SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        self.streamPlaylist()
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didReceive event: SpPlaybackEvent) {
//        print("EVENT: \(event.rawValue)")
        if event == SPPlaybackNotifyPlay {
            audioStreaming.setShuffle(true, callback: { error in
                guard error == nil else {
                    print("Error setting shuffle state: \(String(describing: error?.localizedDescription))")
                    return
                }
            })
        }
    }
    
    func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController!) {
        if let player = self.player, let callback = self.cleanupCallback {
            do {
                try player.stop()
                SPTAuth.defaultInstance().session = nil
                callback(nil)
            } catch {
                callback("Error stopping Spotify player")
            }
        }
    }
    
    func streamPlaylist() {
        if let player = self.player {
            player.playSpotifyURI(self.playableUri, startingWith: 0, startingWithPosition: 0, callback: { error in
                if (error != nil) {
                    print("Error playing song: \(String(describing: error?.localizedDescription))")
                }
            })
            self.initializeMicTap()
        }
    }
    
    func initializeMicTap() {
        let inputNode = audioEngine.inputNode
        let bus = 0
        audioEngine.inputNode.removeTap(onBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 2048, format: inputNode.inputFormat(forBus: bus)) {
            (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
            buffer.frameLength = 2048
            let inNumberFrames = buffer.frameLength
            let trigFilter: Float = 0.01
            if (buffer.format.channelCount > 0) {
                let samples = buffer.floatChannelData![0]
                var avgValue: Float = 0
                
                // https://stackoverflow.com/questions/30641439/level-metering-with-avaudioengine
                vDSP_meamgv(samples, 1, &avgValue, vDSP_Length(inNumberFrames))
                let tempVal = ((avgValue == 0) ? -100 : 20.0 * log10f(avgValue))
                let partTwo = ((1.0 - trigFilter) * self.channel0Power)
                self.channel0Power = (trigFilter * tempVal) + partTwo
                self.updateOrb()
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            print(error)
        }
    }
    
    func updateOrb() {
        // (input or power - minPower) / (dynamicMaxPower - minPower)
        if self.channel0Power > self.maxPowerLevel {
            self.maxPowerLevel = self.channel0Power
        }
        var percentInRange = ((self.channel0Power - self.minPowerLevel)) / (self.maxPowerLevel - minPowerLevel)
        if percentInRange < 0 { percentInRange = 0 }
        
        let birthRate = percentInRange * 300
//        print("birthrate: \(birthRate)")
        self.orbParticleSystem.birthRate = CGFloat(birthRate)
        let particleVelocity = percentInRange * 2
//        print("velocity: \(particleVelocity)")
        self.orbParticleSystem.particleVelocity = CGFloat(particleVelocity)
        let particleSize = percentInRange * 0.20
//        print("size: \(particleSize)")
        self.orbParticleSystem.particleSize = CGFloat(particleSize)
    }
}

