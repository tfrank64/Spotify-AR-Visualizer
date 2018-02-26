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
    
    @IBOutlet weak var playlistTableView: UITableView!
    @IBOutlet weak var loginButton: UIButton!
    var auth = SPTAuth.defaultInstance()!
    var session: SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    var authViewController: UIViewController!
    var masterPlaylistList = [SPTPartialPlaylist]()
    var nextPlaylistPageRequest: URLRequest?

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
            print("Error: Next page URLRequest is nil, there are no more playlists to load.")
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
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

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
