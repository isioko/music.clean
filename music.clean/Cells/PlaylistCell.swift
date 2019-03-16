//
//  PlaylistCell.swift
//  music.clean
//
//  Created by Isi Okojie on 3/15/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit

class PlaylistCell: UICollectionViewCell {
    static let reuseIdentifier = "playlistCell"

    @IBOutlet weak var playlistNameLabel: UILabel!
    
    func displayContent(playlistName: String) {
        playlistNameLabel.text = playlistName
    }
}
