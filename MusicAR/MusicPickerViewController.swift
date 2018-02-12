//
//  MusicPickerViewController.swift
//  MusicAR
//
//  Created by Taylor Franklin on 2/11/18.
//  Copyright © 2018 Taylor Franklin. All rights reserved.
//

import UIKit

class MusicPickerViewController: UIViewController {
    
    var auth = SPTAuth.defaultInstance()!
    var session:SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        sdkSetup()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func sdkSetup() {
        auth.clientID = ""
        auth.redirectURL = "" // TODO: finish this
    }

}
