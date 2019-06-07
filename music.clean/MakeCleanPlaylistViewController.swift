//
//  MakeCleanPlaylistViewController.swift
//  music.clean
//
//  Created by Isi Okojie on 3/31/19.
//  Copyright © 2019 Isi Okojie. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class MakeCleanPlaylistViewController: UIViewController {
    /* Steps:
     1. Create a new empty playlist
     2. Add all already clean songs to playlist
     3. Search for clean versions of explicit songs and add to the playlist
    */
    
    var playlistID = ""
    var selectedPlaylistName = ""
    var playlistTracks = [Track]()
    var newPlaylistID = ""
    var cleanTracks = [String]() // Contains trackURIs of clean tracks
    var explicitTracks = [Track]()
    var cleanedTracks = [String]() // Contains trackURIs of cleaned tracks from search
    
    override func viewDidLoad() {
        selectedPlaylistName = UserDefaults.standard.string(forKey: "selectedPlaylistName")!
        
        // Start task 1: Create a new empty playlist
        let semaphore = DispatchSemaphore(value: 0)

        let newPlaylistName = selectedPlaylistName + " CLEANED"
        spotifyManager.createPlaylist(name: newPlaylistName, completionHandler: { newID in
            semaphore.signal()
            self.newPlaylistID = newID
        })
        
        semaphore.wait()
        // End task 1: Create a new empty playlist
        
        // Task 2: Filter clean and explicit songs
        filterExplicitTracks()
    
        // Task 3: Add already clean songs
        spotifyManager.addTracksToPlaylist(playlistID: newPlaylistID, uris: cleanTracks)
        
        // Task 4: Search for clean versions of explicit songs and get uris
        let track = explicitTracks[0] // DEV :: for dev purposes only do one track change to for loop later
        spotifyManager.searchForCleanVersion(trackName: track.trackName, trackArtists: track.artistName, completionBlock: { cleanTrackURI in
            self.cleanedTracks.append(cleanTrackURI)
            semaphore.signal()
        })
        
        semaphore.wait()
        // End task 4
        
        print("cleaned tracks", cleanedTracks)
        
        // Task 5: Add newly cleaned songs
        spotifyManager.addTracksToPlaylist(playlistID: newPlaylistID, uris: cleanedTracks)
    }
    
    // TAKE OUT OR ADD to viewDidLoad
    func createNewPlaylist() {
        let newPlaylistName = selectedPlaylistName + " CLEANED"
        spotifyManager.createPlaylist(name: newPlaylistName, completionHandler: { newID in
            self.newPlaylistID = newID
        })
    }
    
    func filterExplicitTracks() {
        for track in playlistTracks {
            if track.explicit {
                explicitTracks.append(track)
            } else {
                cleanTracks.append(track.trackURI)
            }
        }
    }

    func getSelectedPlaylistID() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        // Fetch the selected playlist object from CoreData
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Playlist")
        request.predicate = NSPredicate(format: "playlistName == %@", selectedPlaylistName)
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            for data in result as! [NSManagedObject] {
                // Set the information of the playlist for later reference
                self.playlistID = data.value(forKey: "playlistID") as! String
            }
        } catch { // Could not fetch playlist
            print("Failed")
        }
    }
}
