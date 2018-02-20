//
//  MusicPickerViewController.swift
//  MusicAR
//
//  Created by Taylor Franklin on 2/11/18.
//  Copyright © 2018 Taylor Franklin. All rights reserved.
//

import UIKit
import SafariServices

class MusicPickerViewController: UIViewController {
    
    @IBOutlet weak var loginButton: UIButton!
    var auth = SPTAuth.defaultInstance()!
    var session: SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    var authViewController: UIViewController!
    var latestPlaylistList: SPTPlaylistList?

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
            print("session Valid: \(currentSession.expirationDate)")
            self.session = currentSession
            initializePlayer(authSession: self.session)
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
            initializePlayer(authSession: self.session)
        }
    }

    @IBAction func login(_ sender: Any) {
        if let authURL = loginUrl {
            self.authViewController = SFSafariViewController(url: authURL)
            self.present(self.authViewController, animated: true, completion: nil)
        }
    }
    
    func initializePlayer(authSession: SPTSession) {
        if self.player == nil {
            self.player = SPTAudioStreamingController.sharedInstance()
            self.player!.playbackDelegate = self
            self.player!.delegate = self
            try! player!.start(withClientId: auth.clientID)
            self.player!.login(withAccessToken: authSession.accessToken)
        }
    }
    
    func setupPlaylists() {
        // if already setup, don't do again
        if self.loginButton.isHidden {
            return
        }
        self.loginButton.isHidden = true
        
        SPTPlaylistList.playlists(forUser: self.session.canonicalUsername, withAccessToken: self.session.accessToken)
        { (error, playlistData) in
            guard error == nil, let playlists = playlistData as? SPTPlaylistList, let partialPlaylists = playlists.items as? [SPTPartialPlaylist] else {
                print("Error getting playlists: \(String(describing: error?.localizedDescription))")
                return
            }
            
            if self.latestPlaylistList == nil {
                self.latestPlaylistList = playlists
            }
            
            for playlist in partialPlaylists {
                print("plist: \(playlist.name)")
                // add to data list
            }
        }
    }
    
    // create method to detect when scrolled to bottom
    // if so, do call to get next playlist and add to data object (not created yet)
    // continually getlatest playlist and call nextPlaylist...
    // if no more pages, ignore call.
}

extension MusicPickerViewController: SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("logged in")
        setupPlaylists()
//        self.player?.playSpotifyURI("spotify:track:2pJZ1v8HezrAoZ0Fhzby92", startingWith: 0, startingWithPosition: 0, callback: { (error) in
//            if (error != nil) {
//                print("Error playing song: \(String(describing: error?.localizedDescription))")
//            }
//            print("playing!")
//        })
    }
    
}
