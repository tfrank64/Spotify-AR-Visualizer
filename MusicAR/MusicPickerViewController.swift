
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
    var selectedParticleColor = UIColor.blue
    
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
        }
        return self.masterPlaylistList.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Settings"
        }
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
        if indexPath.section == 0 {
            let cell = UITableViewCell()
            cell.textLabel?.text = indexPath.row == 0 ? "Color Settings" : "Microphone Listener"
            return cell
        }
        
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
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if indexPath.section == 0 {
            
            let handler = { (action: UIAlertAction) in
                switch action.title! {
                    case "Red": self.selectedParticleColor = UIColor.red
                    case "Blue": self.selectedParticleColor = UIColor.blue
                    case "Green": self.selectedParticleColor = UIColor.green
                    case "Yellow": self.selectedParticleColor = UIColor.yellow
                    case "Purple": self.selectedParticleColor = UIColor.purple
                    case "Cyan": self.selectedParticleColor = UIColor.cyan
                    case "Orange": self.selectedParticleColor = UIColor.orange
                    default: self.selectedParticleColor = UIColor.blue
                }
            }
            
            if indexPath.row == 0 {
                // launch color settings
                let colorMenu = UIAlertController(title: nil, message: "Select a color", preferredStyle: .actionSheet)
                let redAction =  UIAlertAction(title: "Red", style: .default, handler: handler)
                let blueAction =  UIAlertAction(title: "Blue", style: .default, handler: handler)
                let greenAction =  UIAlertAction(title: "Green", style: .default, handler: handler)
                let yellowAction =  UIAlertAction(title: "Yellow", style: .default, handler: handler)
                let purpleAction =  UIAlertAction(title: "Purple", style: .default, handler: handler)
                let cyanAction =  UIAlertAction(title: "Cyan", style: .default, handler: handler)
                let orangeAction =  UIAlertAction(title: "Orange", style: .default, handler: handler)
                let cancelAction =  UIAlertAction(title: "Cancel", style: .destructive, handler: nil)
                colorMenu.addAction(redAction)
                colorMenu.addAction(blueAction)
                colorMenu.addAction(greenAction)
                colorMenu.addAction(yellowAction)
                colorMenu.addAction(purpleAction)
                colorMenu.addAction(cyanAction)
                colorMenu.addAction(orangeAction)
                colorMenu.addAction(cancelAction)
                self.present(colorMenu, animated: true, completion: nil)
            } else {
                // launch AR view, no song
                if let orbVC = storyboard.instantiateViewController(withIdentifier: "OrbViewController") as? OrbViewController {
                    orbVC.spotifyPlaylistURI = ""
                    orbVC.selectedParticleColor = self.selectedParticleColor
                    self.present(orbVC, animated: true, completion: nil)
                }
            }
        } else {
            let playlistItem = self.masterPlaylistList[indexPath.item]
            if let orbVC = storyboard.instantiateViewController(withIdentifier: "OrbViewController") as? OrbViewController {
                orbVC.spotifyPlaylistURI = playlistItem.playableUri.absoluteString
                orbVC.selectedParticleColor = self.selectedParticleColor
                self.present(orbVC, animated: true, completion: nil)
            }
        }
        
    }
}
