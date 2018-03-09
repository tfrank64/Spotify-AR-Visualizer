//
//  MusicPickerViewController.swift
//  MusicAR
//
//  Created by Taylor Franklin on 2/11/18.
//  Copyright © 2018 Taylor Franklin. All rights reserved.
//

import UIKit
import SafariServices
import AVFoundation
import Accelerate

class MusicPickerViewController: UIViewController {
    
    @IBOutlet weak var playlistTableView: UITableView!
    @IBOutlet weak var loginButton: UIButton!
    var auth = SPTAuth.defaultInstance()!
    var session: SPTSession!
//    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    var isAuthenticated = false
    var authViewController: UIViewController!
    var masterPlaylistList = [SPTPartialPlaylist]()
    var nextPlaylistPageRequest: URLRequest?
    let audioEngine = AVAudioEngine()
    
    var channel0Power: Float = 0
    var channel1Power: Float = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sdkSetup()
        NotificationCenter.default.addObserver(self, selector: #selector(updateAfterFirstLogin), name: Notification.Name(rawValue: "loginSuccessfull"), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func sdkSetup() {
        auth.clientID = "0064a012b4474a3e9255941f27f1f27d"
        auth.redirectURL = URL(string: "music-ar-login://callback")
        auth.requestedScopes = [SPTAuthStreamingScope, SPTAuthPlaylistReadPrivateScope, SPTAuthPlaylistModifyPublicScope, SPTAuthPlaylistModifyPublicScope]
        loginUrl = auth.spotifyWebAuthenticationURL()
        
        if let currentSession = getStoredSession() {
            self.session = currentSession
//            initializePlayer(authSession: self.session)
            setupPlaylists()
        }
    }
    
    func getStoredSession() -> SPTSession? {
        if let sessionObj: Any = UserDefaults.standard.object(forKey: "SpotifySession") as Any?,
            let sessionDataObj = sessionObj as? Data,
            let mySession = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as? SPTSession,
            mySession.isValid() {
            return mySession
        }
        return nil
    }
    
    @objc func updateAfterFirstLogin() {
        if let firstTimeSession = getStoredSession() {
            self.authViewController.dismiss(animated: true, completion: nil)
            self.session = firstTimeSession
//            initializePlayer(authSession: self.session)
        }
    }

    @IBAction func login(_ sender: Any) {
        if let authURL = loginUrl {
            self.authViewController = SFSafariViewController(url: authURL)
            self.present(self.authViewController, animated: true, completion: nil)
        }
    }
    
//    func initializePlayer(authSession: SPTSession) {
//        if self.player == nil {
//            self.player = SPTAudioStreamingController.sharedInstance()
//            self.player!.playbackDelegate = self
//            self.player!.delegate = self
//            try! player!.start(withClientId: auth.clientID)
//            self.player!.login(withAccessToken: authSession.accessToken)
//        }
//    }
    
    func setupPlaylists() {
        // if already setup, don't do again
        if self.loginButton.isHidden {
            return
        }
        self.loginButton.isHidden = true
        self.playlistTableView.isHidden = false
        
        SPTPlaylistList.playlists(forUser: self.session.canonicalUsername, withAccessToken: self.session.accessToken)
        { (error, playlistData) in
            guard error == nil, let playlists = playlistData as? SPTPlaylistList, let partialPlaylists = playlists.items as? [SPTPartialPlaylist] else {
                print("Error getting playlists: \(String(describing: error?.localizedDescription))")
                return
            }
            print("hasNextPage? \(playlists.hasNextPage) and nextPage: \(playlists.nextPageURL)")
            self.masterPlaylistList = partialPlaylists
            if playlists.hasNextPage {
                do {
                    self.nextPlaylistPageRequest = try playlists.createRequestForNextPage(withAccessToken: self.session.accessToken)
                } catch {
                    print("Failed to get next playlist page request: \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                self.playlistTableView.reloadData()
            }
        }
    }
    
    func addNextPlaylistPage() {
        if let nextPageUrlRequest = self.nextPlaylistPageRequest {
            SPTRequest.sharedHandler().perform(nextPageUrlRequest, callback: { (error, response, data) in
                guard error == nil, let resp = response, let playlistData = data else {
                    print("Error getting next playlist: \(String(describing: error?.localizedDescription))")
                    return
                }
                do {
                    let playlists = try SPTPlaylistList(from: playlistData, with: resp)
                    if let partialPlaylists = playlists.items as? [SPTPartialPlaylist] {
                        print("hasNextPage? \(playlists.hasNextPage) and nextPage: \(playlists.nextPageURL)")
                        self.masterPlaylistList += partialPlaylists
                        if playlists.hasNextPage {
                            do {
                                self.nextPlaylistPageRequest = try playlists.createRequestForNextPage(withAccessToken: self.session.accessToken)
                            } catch {
                                print("Failed to get next playlist page request: \(error.localizedDescription)")
                            }
                        } else {
                            self.nextPlaylistPageRequest = nil
                        }
                        DispatchQueue.main.async {
                            self.playlistTableView.reloadData()
                        }
                    }
                } catch {
                    print(error.localizedDescription)
                }
            })
        } else {
            print("Warning: Next page URLRequest is nil, there are no more playlists to load.")
        }
    }
}

extension MusicPickerViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.masterPlaylistList.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Select Playlist"
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.item + 1 == self.masterPlaylistList.count {
            self.addNextPlaylistPage()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "playlistCell", for: indexPath) as? UserPlaylistTableViewCell else {
            print("Failed to create PlaylistTableViewCell")
            return UITableViewCell()
        }
        let playlistItem = self.masterPlaylistList[indexPath.item]
        cell.playlistTitle.text = playlistItem.name
        cell.playlistTracksLabel.text = playlistItem.trackCount == 1 ? "1 song" : "\(playlistItem.trackCount) songs"
        if playlistItem.smallestImage != nil {
            cell.playlistImageView.imageFromServerURL(url: playlistItem.smallestImage.imageURL, defaultImage: "default")
        } else {
            cell.playlistImageView.image = UIImage(named: "default")
        }
        print("playable uri: \(playlistItem.playableUri)")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let playlistItem = self.masterPlaylistList[indexPath.item]
//        self.streamPlaylist(playlistUri: playlistItem.playableUri)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let orbVC = storyboard.instantiateViewController(withIdentifier: "OrbViewController") as? OrbViewController {
            orbVC.spotifyData = (self.session, playlistItem.playableUri.absoluteString)
            self.present(orbVC, animated: true, completion: nil)
        }
        
    }
}

/*extension MusicPickerViewController: SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("logged in")
        self.isAuthenticated = true
        self.setupPlaylists()
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
    
    func streamPlaylist(playlistUri: URL) {
        if let player = self.player, self.isAuthenticated {
  
            player.playSpotifyURI(playlistUri.absoluteString, startingWith: 0, startingWithPosition: 0, callback: { error in
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
//            print("time: \(AVAudioTime.seconds(forHostTime: time.hostTime))")
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
}*/

// TODO: move to separate file
class UserPlaylistTableViewCell: UITableViewCell {
    @IBOutlet weak var playlistImageView: UIImageView!
    @IBOutlet weak var playlistTitle: UILabel!
    @IBOutlet weak var playlistTracksLabel: UILabel!
}

extension UIImageView {
    public func imageFromServerURL(url: URL, defaultImage: String?) {
        if let defaultImg = defaultImage {
            self.image = UIImage(named: defaultImg)
        }
        
        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
            guard error == nil, let imageData = data else {
                print("Error getting image data: \(String(describing: error?.localizedDescription))")
                return
            }
            DispatchQueue.main.async {
                let image = UIImage(data: imageData)
                self.image = image
            }
            
        }).resume()
    }
}
