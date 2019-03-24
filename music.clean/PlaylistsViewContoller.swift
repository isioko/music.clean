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
    var playlistIDs = [String]()
    var trackNames = [String]()
    var trackInfo = [(String, String, Bool)]()
    
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
            playlistNames.forEach { playlist in
                group.enter()
                
                self.playlistNames.append(playlist.0)
                self.playlistIDs.append(playlist.1)

                group.leave()
            }
            donePlaylists = true
            
            if donePlaylists {
//                print("Playlist Names:", playlistNames)
            self.playlistsCollectionView.performSelector(onMainThread: #selector(UICollectionView.reloadData), with: nil, waitUntilDone: true)
            }
        }
        
        func getAllExplicitTracks() {
            
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let selectedPlaylistID = playlistIDs[indexPath.row]
        var doneTracks = false
        spotifyManager.getAllTracksInPlaylist(playlistID: selectedPlaylistID) { (trackNames) in
            
            let group = DispatchGroup()
            trackNames.forEach { track in
                group.enter()
                
                self.trackNames.append(track.0)
                
                group.leave()
            }
            doneTracks = true
            print(trackNames)
        }
    }
}
