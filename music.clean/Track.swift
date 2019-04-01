//
//  Track.swift
//  music.clean
//
//  Created by Isi Okojie on 3/27/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit

class Track {
    // (trackName, trackID, artists, artworkImage, explicit)
    public var trackName: String
    public var trackID: String
    public var artistName: String
    public var artworkImage: String
    public var trackURI: String
    public var explicit: Bool
    
    init() {
        self.trackName = ""
        self.trackID = ""
        self.artistName = ""
        self.artworkImage = ""
        self.trackURI = ""
        self.explicit = false
    }
}
