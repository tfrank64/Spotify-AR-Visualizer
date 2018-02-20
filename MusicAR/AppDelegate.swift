//
//  AppDelegate.swift
//  MusicAR
//
//  Created by Taylor Franklin on 1/23/18.
//  Copyright © 2018 Taylor Franklin. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var auth = SPTAuth()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        auth.redirectURL = URL(string: "music-ar-login://callback")
        auth.sessionUserDefaultsKey = "currentSession"
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if auth.canHandle(auth.redirectURL) {
            auth.handleAuthCallback(withTriggeredAuthURL: url, callback: { (error, session) in

                guard error == nil, let spotifySession = session else {
                    print("error: \(String(describing: error?.localizedDescription))")
                    return
                }

                let userDefaults = UserDefaults.standard
                let sessionData = NSKeyedArchiver.archivedData(withRootObject: spotifySession)
                userDefaults.set(sessionData, forKey: "SpotifySession")
                userDefaults.synchronize()

                NotificationCenter.default.post(name: Notification.Name(rawValue: "loginSuccessfull"), object: nil)
            })
            return true
        }
        return false
    }

}
