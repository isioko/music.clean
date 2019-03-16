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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    // Authourize user's Spotify account
    @IBAction func clickAuthorize(_ sender: Any) {
        spotifyManager.authorize()
    }
}

