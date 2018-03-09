import Foundation
import SceneKit
import ARKit
import AVFoundation
import Accelerate

class Orb: SCNNode, AVAudioPlayerDelegate {
    
    var anchor: ARPlaneAnchor
    var session: SPTSession
    var playableUri: String
    
    var orbParticleSystem: SCNParticleSystem!
    var audioPlayer: AVAudioPlayer!
    var audioTimer: Timer?
    var isPlaying = false
    var baseSoundPower: Float = 0
    var audioChanges: Float = 1
    
    var player: SPTAudioStreamingController?
    var isAuthenticated = false
    let audioEngine = AVAudioEngine()
    var channel0Power: Float = 0
    var channel1Power: Float = 0
    
    init(anchor: ARPlaneAnchor, spotifyData: (SPTSession, String)) {
        
        self.anchor = anchor
        self.session = spotifyData.0 // TODO: could read from local storage later
        self.playableUri = spotifyData.1
        super.init()
        setup()
        initializePlayer(authSession: self.session)
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
    
    func initializePlayer(authSession: SPTSession) {
        if self.player == nil, let auth = SPTAuth.defaultInstance() {
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

    func beginPlayingMusic() {
//        if let audioFileURL = Bundle.main.url(forResource: "spiderManTheme", withExtension: "mp3") {
//            do {
//                self.audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
//                self.audioPlayer.isMeteringEnabled = true
//                self.audioPlayer.delegate = self
//                DispatchQueue.main.async {
//                    if self.audioTimer == nil {
//                        self.audioTimer = Timer.scheduledTimer(timeInterval: 0.2,
//                                                               target: self,
//                                                               selector: #selector(self.monitorAudioPlayer),
//                                                               userInfo: nil,
//                                                               repeats: true)
//                    }
//                    self.playPauseMusic()
//                }
//            } catch {
//                print("Cannot init audio player: \(error.localizedDescription)")
//            }
//        }
        
        // play spotify music
        
    }
    
    func playPauseMusic() {
        if self.isPlaying {
            self.audioPlayer.pause()
        } else {
            self.audioPlayer.play()
        }
        self.isPlaying = !self.isPlaying
    }
    
    @objc func monitorAudioPlayer() {
        self.audioPlayer.updateMeters()
        guard self.audioPlayer.numberOfChannels > 0 else { return }
        let peakPower = self.audioPlayer.peakPower(forChannel: 0)

        // Get average start power as a baseline
        if self.audioChanges <= 5 {
            self.baseSoundPower = self.baseSoundPower + peakPower
            if self.audioChanges == 5 {
                self.baseSoundPower = self.baseSoundPower / self.audioChanges
            }
            self.audioChanges += 1
            return
        }
        let valueInRange = (peakPower - self.baseSoundPower)/(0 - self.baseSoundPower)
        let birthRate = valueInRange * 300 //(x - start)/(end - start)
//        print("birthrate: \(birthRate)")
        self.orbParticleSystem.birthRate = CGFloat(birthRate)
        print("valueInrange: \(valueInRange)")
        let particleVelocity = valueInRange * 2
//        print("velocity: \(particleVelocity)")
        self.orbParticleSystem.particleVelocity = CGFloat(particleVelocity)
        let particleSize = valueInRange * 0.25
//        print("size: \(particleSize)")
        self.orbParticleSystem.particleSize = CGFloat(particleSize)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.audioTimer != nil else { return }
        self.audioTimer?.invalidate()
        self.audioTimer = nil
    }
}

extension Orb: SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("logged in")
        self.isAuthenticated = true // TODO: may not need?
        self.streamPlaylist()
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didReceive event: SpPlaybackEvent) {
        print("EVENT: \(event.rawValue)")
        if event == SPPlaybackNotifyPlay {
            audioStreaming.setShuffle(true, callback: { error in
                guard error == nil else {
                    print("Error setting shuffle state: \(String(describing: error?.localizedDescription))")
                    return
                }
            })
        }
    }
    
    func streamPlaylist() {
        if let player = self.player, self.isAuthenticated {
            player.playSpotifyURI(self.playableUri, startingWith: 0, startingWithPosition: 0, callback: { error in
                if (error != nil) {
                    print("Error playing song: \(String(describing: error?.localizedDescription))")
                }
                
            })
            self.audioConnection()
        }
    }
    
    func audioConnection() {
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
                
                vDSP_meamgv(samples, 1, &avgValue, vDSP_Length(inNumberFrames)) // max about -50
                //                vDSP_maxmgv(samples, 1, &avgValue, vDSP_Length(inNumberFrames)) // max about -39
                let tempVal = ((avgValue == 0) ? -100 : 20.0 * log10f(avgValue))
                let partTwo = ((1.0 - trigFilter) * self.channel0Power)
                self.channel0Power = (trigFilter * tempVal) + partTwo
                self.channel1Power = self.channel0Power
                print("channel Power0: \(self.channel0Power)")
            }
            if (buffer.format.channelCount > 1) {
                let samples = buffer.floatChannelData![1]
                var avgValue: Float = 0
                
                vDSP_meamgv(samples, 1, &avgValue, vDSP_Length(inNumberFrames))
                //                vDSP_maxmgv(samples, 1, &avgValue, vDSP_Length(inNumberFrames))
                let tempVal = ((avgValue == 0) ? -100 : 20.0 * log10f(avgValue))
                let partTwo = ((1.0 - trigFilter) * self.channel1Power)
                self.channel1Power = (trigFilter * tempVal) + partTwo
                print("channel Power1: \(self.channel1Power)")
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            print(error)
        }
    }
}

