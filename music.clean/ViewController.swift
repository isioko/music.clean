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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        spotifyManager.refreshTokenIfNeeded()
    }

    // Authourize user's Spotify account
    @IBAction func clickAuthorize(_ sender: Any) {
        spotifyManager.authorize()
    }
    
    @IBAction func clickDeauthorize(_ sender: Any) {
        spotifyManager.deauthorize()
    }
}

