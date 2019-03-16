//
//  PlaylistsViewContoller.swift
//  music.clean
//
//  Created by Isi Okojie on 3/15/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit

class PlaylistsViewContoller: UIViewController, UICollectionViewDataSource {
    
    var playlistNames = [String]()
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return playlistNames.count
    }
    
    @IBOutlet weak var playlistsCollectionView: UICollectionView! {
        didSet {
            playlistsCollectionView.dataSource = self
            playlistsCollectionView.delegate = self as? UICollectionViewDelegate
        }
    }
    
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
            self.playlistsCollectionView.performSelector(onMainThread: #selector(UICollectionView.reloadData), with: nil, waitUntilDone: true)
            }
        }
        
//        DispatchQueue.main.async {
//            self.playlistsCollectionView.reloadData()
//        }

        
//        spotifyManager.createPlaylist(name: "new")
//        print("done")
    }
}

extension PlaylistsViewContoller: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "playlistCell", for: indexPath) as! PlaylistCell
        
        let playlist = playlistNames[indexPath.row]
        cell.displayContent(playlistName: playlist)
        
        return cell
    }
}
