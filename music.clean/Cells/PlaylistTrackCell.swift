//
//  PlaylistTrackCell.swift
//  music.clean
//
//  Created by Isi Okojie on 3/27/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit

class PlaylistTrackCell: UITableViewCell {
    static let reuseIdentifier = "playlistTrackCell"
    
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var explicit: UIImageView!
    
    func displayContent(track: Track) {
        trackNameLabel.text = track.trackName
        artistNameLabel.text = track.artistName
        
        let url = URL(string: track.artworkImage)
        if url != nil {
            do {
                let data = try Data(contentsOf: url!)
                let image = UIImage(data: data)
                artworkImage.image = image
            } catch {
                print("error")
            }
        }
    }
}
