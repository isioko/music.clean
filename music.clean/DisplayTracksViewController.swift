//
//  DisplayTracksViewController.swift
//  music.clean
//
//  Created by Isi Okojie on 3/27/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//
//  PURPOSE: Display tracks of selected playlist table view

import Foundation
import UIKit
import CoreData

class DisplayTracksViewController: UIViewController, UITableViewDataSource {
    
    var playlistName = ""
    var playlistID = ""
    var numTracks = 0
    
    public var playlistTracks = [Track]()
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlistTracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playlistTrackCell", for: indexPath) as! PlaylistTrackCell
        let track = playlistTracks[indexPath.row]
        cell.displayContent(track: track)
        
        if !track.explicit {
            cell.explicit.isHidden = true
        }

        cell.setNeedsLayout()
        
        return cell
    }
    
    @IBOutlet weak var playlistNameLabel: UILabel!
    
    override func viewDidLoad() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let selectedPlaylistName = UserDefaults.standard.string(forKey: "selectedPlaylistName")
        playlistNameLabel.text = selectedPlaylistName
        self.playlistName = selectedPlaylistName!
        
        // Fetch the selected playlist object from CoreData
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Playlist")
        request.predicate = NSPredicate(format: "playlistName == %@", selectedPlaylistName!)
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            for data in result as! [NSManagedObject] {
                // Set the information of the playlist for later reference
                self.playlistID = data.value(forKey: "playlistID") as! String
                self.numTracks = data.value(forKey: "numTracks") as! Int
            }
        } catch { // Could not fetch playlist
            print("Failed")
        }
        
        getTracksInPlaylist()
    }
    
    func getTracksInPlaylist() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        var doneTracks = false
        
        spotifyManager.getAllTracksInPlaylist(playlistID: self.playlistID) { (tracks) in
    
            let group = DispatchGroup()
            tracks.forEach { track in
                group.enter()
                
                // Start: Add track info to CoreData
                let entity = NSEntityDescription.entity(forEntityName: "PlaylistTrack", in: context)
                let newPlaylist = NSManagedObject(entity: entity!, insertInto: context)
                newPlaylist.setValue(track.0, forKey: "trackName")
                newPlaylist.setValue(track.1, forKey: "trackID")
                newPlaylist.setValue(track.2, forKey: "artistName")
                newPlaylist.setValue(track.3, forKey: "artworkImage")
                // Add trackURI
                newPlaylist.setValue(track.5, forKey: "explicit")
                
                do {
                    try context.save()
                } catch {
                    print("Failed saving")
                }
                // End: Add track info to CoreData
                
                // Start: Add track info to playlistTracks
                let newTrack = Track()
                newTrack.trackName = track.0
                newTrack.trackID = track.1
                newTrack.artistName = track.2
                newTrack.artworkImage = track.3
                newTrack.trackURI = track.4
                newTrack.explicit = track.5
                
                if newTrack.trackName != "" { // if not an empty track
                    self.playlistTracks.append(newTrack)
                }
                // End: Add track info to playlistTracks
                
                group.leave()
            }
            
            doneTracks = true
            if doneTracks {
                // Reload table view data on main thread
                self.tracksTableView.performSelector(onMainThread: #selector(UITableView.reloadData), with: nil, waitUntilDone: true)
            }
        }
    }
    
    @IBOutlet weak var tracksTableView: UITableView! {
        didSet {
            tracksTableView.dataSource = self
            tracksTableView.delegate = self as? UITableViewDelegate
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toCleanPlaylist" {
            if let tcp = segue.destination as? MakeCleanPlaylistViewController {
                tcp.playlistTracks = playlistTracks
            }
        }
    }
}
