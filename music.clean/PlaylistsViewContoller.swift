//
//  PlaylistsViewContoller.swift
//  music.clean
//
//  Created by Isi Okojie on 3/15/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit

class PlaylistsViewContoller: UIViewController /*, UICollectionViewDataSource*/ {
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        <#code#>
//    }
//
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        <#code#>
//    }
    
    var playlistNames = [String]()
    
    override func viewDidLoad() {        
        var donePlaylists = false
        spotifyManager.getListOfPlaylists { (playlistNames) in
            let group = DispatchGroup()
            playlistNames.forEach { name in
                group.enter()
                
                self.playlistNames.append(name)

                group.leave()
            }
            donePlaylists = true
            
            if donePlaylists {
                print("Playlist Names:", playlistNames)
            }
        }
        
        spotifyManager.createPlaylist(name: "new")
        print("done")
    }
}

//extension PlaylistsViewContoller: UICollectionViewDelegateFlowLayout {
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        let cell_width = collectionView.bounds.width
//        let cell_height: CGFloat = 105
//        return CGSize(width: cell_width, height: cell_height)
//    }
//}
