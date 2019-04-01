//
//  PlaylistsViewContoller.swift
//  music.clean
//
//  Created by Isi Okojie on 3/15/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit
import CoreData

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
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext

        var donePlaylists = false
        spotifyManager.getListOfPlaylists { (playlists) in
            let group = DispatchGroup()
            playlists.forEach { playlist in
                group.enter()
                
                // Start: Add playlist info to CoreData
                let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context)
                let newPlaylist = NSManagedObject(entity: entity!, insertInto: context)
                newPlaylist.setValue(playlist.0, forKey: "playlistName")
                newPlaylist.setValue(playlist.1, forKey: "playlistID")
                newPlaylist.setValue(playlist.2, forKey: "numTracks")
                
                do {
                    try context.save()
                } catch {
                    print("Failed saving")
                }
                // End: Add playlist info to CoreData

                
                self.playlistNames.append(playlist.0)
                self.playlistIDs.append(playlist.1)

                group.leave()
            }
            donePlaylists = true
            
            if donePlaylists {
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
        let selectedPlaylistName = playlistNames[indexPath.row]
        UserDefaults.standard.set(selectedPlaylistName, forKey: "selectedPlaylistName")
        performSegue(withIdentifier: "toPlaylistTracks", sender: nil)
    }
}
