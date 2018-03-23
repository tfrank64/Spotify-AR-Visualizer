
import UIKit
import SafariServices
import AVFoundation
import Accelerate

class MusicPickerViewController: UIViewController {
    
    @IBOutlet weak var playlistTableView: UITableView!
    @IBOutlet weak var loginButton: UIButton!
    var auth = SPTAuth.defaultInstance()!
    var session: SPTSession!
    var loginUrl: URL?
    var isAuthenticated = false
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
        
        if let currentSession = SPTSession.getStoredSession() {
            self.session = currentSession
            setupPlaylists()
        }
    }
    
    @objc func updateAfterFirstLogin() {
        if let firstTimeSession = SPTSession.getStoredSession() {
            self.authViewController.dismiss(animated: true, completion: nil)
            self.session = firstTimeSession
            self.setupPlaylists()
        }
    }

    @IBAction func login(_ sender: Any) {
        if let authURL = loginUrl {
            self.authViewController = SFSafariViewController(url: authURL)
            self.present(self.authViewController, animated: true, completion: nil)
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
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if let orbVC = storyboard.instantiateViewController(withIdentifier: "OrbViewController") as? OrbViewController {
            orbVC.spotifyPlaylistURI = playlistItem.playableUri.absoluteString
            self.present(orbVC, animated: true, completion: nil)
        }
        
    }
}
