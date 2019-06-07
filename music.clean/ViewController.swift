//
//  ViewController.swift
//  music.clean
//
//  Created by Isi Okojie on 3/15/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var authorizeButton: UIButton!
    @IBOutlet weak var deauthButton: UIButton!
    @IBOutlet weak var testSearchButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // Authourize user's Spotify account
    @IBAction func clickAuthorize(_ sender: Any) {
        spotifyManager.authorize()
        spotifyManager.refreshTokenIfNeeded()
    }
    
    @IBAction func clickDeauthorize(_ sender: Any) {
        spotifyManager.deauthorize()
    }
    
    @IBAction func clickTestSearch(_ sender: Any) {
        let trackName = "thank u, next"
        let trackArtists = "Ariana Grande"
        
        spotifyManager.searchForCleanVersion(trackName: trackName, trackArtists: trackArtists)
    }
}

