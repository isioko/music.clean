//
//  SpotifyKit.swift
//  SpotifyKit
//
//  Created by Marco Albera on 30/01/17.
//
//

#if !os(OSX)
    import UIKit
#else
    import AppKit
#endif

// MARK: Token saving options

enum TokenSavingMethod {
    case preference
}

// MARK: Spotify queries addresses

/**
 Parameter names for Spotify HTTP requests
 */
fileprivate struct SpotifyParameter {
    // Search
    static let name = "q"
    static let type = "type"
    
    // Authorization
    static let clientId     = "client_id"
    static let responseType = "response_type"
    static let redirectUri  = "redirect_uri"
    static let scope        = "scope"
    
    // Token
    static let clientSecret = "client_secret"
    static let grantType    = "grant_type"
    static let code         = "code"
    static let refreshToken = "refresh_token"
    
    // User's library
    static let ids          = "ids"
}

/**
 Header names for Spotify HTTP requests
 */
fileprivate struct SpotifyHeader {
    // Authorization
    static let authorization = "Authorization"
}

// MARK: Queries data types

/**
 URLs for Spotify HTTP queries
 */
fileprivate enum SpotifyQuery: String, URLConvertible {
    var url: URL? {
        switch self {
        case .master, .account:
            return URL(string: self.rawValue)
        case .search, .users, .me, .contains:
            return URL(string: SpotifyQuery.master.rawValue + self.rawValue)
        case .authorize, .token:
            return URL(string: SpotifyQuery.account.rawValue + self.rawValue)
        }
    }
    
    // Master URLs
    case master  = "https://api.spotify.com/v1/"
    case account = "https://accounts.spotify.com/"
    
    // Search
    case search    = "search"
    case users     = "users"
    
    // Authentication
    case authorize = "authorize"
    case token     = "api/token"
    
    // User's library
    case me        = "me/"
    case contains  = "me/tracks/contains"
    
    static func libraryUrlFor<T>(_ what: T.Type) -> URL? where T: SpotifyLibraryItem {
        return URL(string: master.rawValue + me.rawValue + what.type.searchKey.rawValue)
    }
    
    static func urlFor<T>(_ what: T.Type,
                          id: String,
                          playlistUserId: String? = nil) -> URL? where T: SpotifySearchItem {
        switch what.type {
        case .track, .album, .artist, .playlist:
            return URL(string: master.rawValue + what.type.searchKey.rawValue + "/\(id)")
        case .user:
            return URL(string: master.rawValue + users.rawValue + "/\(id)")!
        }
    }
}

/**
 Scopes (aka permissions) required by our app
 during authorization phase
 // TODO: test this more
 */
fileprivate enum SpotifyScope: String {
    case readPrivate           = "user-read-private"
    case readEmail             = "user-read-email"
    case libraryModify         = "user-library-modify"
    case libraryRead           = "user-library-read"
    case playlistRead          = "playlist-read-private"
    case playlistModifyPrivate = "playlist-modify-private"
    case playlistModifyPublic  = "playlist-modify-public"
    
    /**
     Creates a string to pass as parameter value
     with desired scope keys
     */
    static func string(with scopes: [SpotifyScope]) -> String {
        return String(scopes.reduce("") { "\($0) \($1.rawValue)" }.dropFirst())
    }
}

fileprivate enum SpotifyAuthorizationResponseType: String {
    case code = "code"
}

fileprivate enum SpotifyAuthorizationType: String {
    case basic  = "Basic "
    case bearer = "Bearer "
}

/**
 Spotify authentication grant types for obtaining token
 */
fileprivate enum SpotifyTokenGrantType: String {
    case authorizationCode = "authorization_code"
    case refreshToken      = "refresh_token"
}

// MARK: Helper class

public class SpotifyManager {
    
    public struct SpotifyDeveloperApplication {
        var clientId:     String
        var clientSecret: String
        var redirectUri:  String
        
        public init(clientId:     String,
                    clientSecret: String,
                    redirectUri:  String) {
            self.clientId     = clientId
            self.clientSecret = clientSecret
            self.redirectUri  = redirectUri
        }
    }
    
    @objc(SpotifyKit)private class SpotifyToken: NSObject, Decodable, NSCoding {
        var accessToken:  String
        var expiresIn:    Int
        var refreshToken: String
        var tokenType:    String
        
        var saveTime: TimeInterval
        
        static let preferenceKey = "spotifyKitToken"
        
        // MARK: Decodable
        
        enum Key: String, CodingKey {
            case access_token, expires_in, refresh_token, token_type, save_time
        }
        
        convenience required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            
            self.init(
                accessToken: try? container.decode(String.self, forKey: .access_token),
                expiresIn: try? container.decode(Int.self, forKey: .expires_in),
                refreshToken: try? container.decode(String.self, forKey: .refresh_token),
                tokenType: try? container.decode(String.self, forKey: .token_type)
            )
        }
        
        // MARK: NSCoding
        
        func encode(with coder: NSCoder) {
            coder.encode(accessToken, forKey: Key.access_token.rawValue)
            coder.encode(expiresIn, forKey: Key.expires_in.rawValue)
            coder.encode(refreshToken, forKey: Key.refresh_token.rawValue)
            coder.encode(tokenType, forKey: Key.token_type.rawValue)
            coder.encode(saveTime, forKey: Key.save_time.rawValue)
        }
        
        required convenience init?(coder decoder: NSCoder) {
            self.init(
                accessToken:  decoder.decodeObject(forKey: Key.access_token.rawValue) as? String,
                expiresIn:    decoder.decodeInteger(forKey: Key.expires_in.rawValue),
                refreshToken: decoder.decodeObject(forKey: Key.refresh_token.rawValue) as? String,
                tokenType:    decoder.decodeObject(forKey: Key.token_type.rawValue) as? String,
                saveTime:     decoder.decodeDouble(forKey: Key.save_time.rawValue)
            )
        }
        
        // MARK: Other
        
        required init(accessToken:  String?,
                      expiresIn:    Int?,
                      refreshToken: String?,
                      tokenType:    String?,
                      saveTime:     TimeInterval? = nil) {
            self.accessToken  = accessToken ?? ""
            self.expiresIn    = expiresIn ?? 0
            self.refreshToken = refreshToken ?? ""
            self.tokenType    = tokenType ?? ""
            self.saveTime     = saveTime ?? Date.timeIntervalSinceReferenceDate
        }
        
        /**
         Writes the contents of the token to a preference.
         */
        func writeToKeychain() {
            Keychain.standard.set(self, forKey: SpotifyToken.preferenceKey)
        }
        
        /**
         Loads the token object from a preference.
         */
        static func loadFromKeychain() -> SpotifyToken? {
            return Keychain.standard.value(forKey: SpotifyToken.preferenceKey) as? SpotifyToken
        }
        
        /**
         Deletes the token object from a preference
         */
        static func deleteFromKeychain() {
            Keychain.standard.delete(objectWithKey: SpotifyToken.preferenceKey)
        }
        
        /**
         Updates a token from a JSON, for instance after calling 'refreshToken',
         when only a new 'accessToken' is provided
         */
        func refresh(from data: Data) {
            guard let token = try? JSONDecoder().decode(SpotifyToken.self,
                                                        from: data) else { return }
            
            accessToken = token.accessToken
            saveTime    = Date.timeIntervalSinceReferenceDate
        }
        
        /**
         Returns whether a token is expired basing on saving time,
         current time and provided duration limit
         */
        var isExpired: Bool {
            return Date.timeIntervalSinceReferenceDate - saveTime > Double(expiresIn)
        }
        
        /**
         Returns true if the token is valid (aka not blank)
         */
        var isValid: Bool {
            return !self.accessToken.isEmpty && !self.refreshToken.isEmpty && !self.tokenType.isEmpty && self.expiresIn != 0
        }
        
        var details: NSString {
            return  """
            Access token:  \(accessToken)
            Expires in:    \(expiresIn)
            Refresh token: \(refreshToken)
            Token type:    \(tokenType)
            """ as NSString
        }
    }
    
    private var application: SpotifyDeveloperApplication?
    
    private var tokenSavingMethod: TokenSavingMethod = .preference
    
    private var applicationJsonURL: URL?
    
    private var token: SpotifyToken?
    
    private var tokenJsonURL: URL?
    
    // MARK: Constructors
        
    public init(with application: SpotifyDeveloperApplication) {
        self.application = application
        
        if let token = SpotifyToken.loadFromKeychain() {
            self.token = token
        }
    }
    
    // MARK: Query functions
    
    private func tokenQuery(operation: @escaping (SpotifyToken) -> ()) {
        guard let token = self.token else { return }
        
        guard !token.isExpired else {
            // If the token is expired, refresh it first
            // Then try repeating the operation
            refreshToken { refreshed in
                if refreshed {
                    operation(token)
                }
            }
            
            return
        }
        
        // Run the requested query operation
        operation(token)
    }

    /**
     Gets a specific Spotify item (track, album, artist or playlist
     - parameter what: the type of the item ('SpotifyTrack', 'SpotifyAlbum'...)
     - parameter id: the item Spotify identifier
     - parameter playlistUserId: the id of the user who owns the requested playlist
     - parameter completionHandler: the block to run when result is found and passed as parameter to it
     */
    public func get<T>(_ what: T.Type,
                       id: String,
                       completionHandler: @escaping ((T) -> Void)) where T: SpotifySearchItem {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.urlFor(what,
                                                          id: id),
                                      method: .GET,
                                      headers: self.authorizationHeader(with: token))
            { result in
                if  case let .success(data) = result,
                    let result = try? JSONDecoder().decode(what,
                                                          from: data) {
                    completionHandler(result)
                }
            }
        }
    }
    
    /**
     Finds items on Spotify that match a provided keyword
     - parameter what: the type of the item ('SpotifyTrack', 'SpotifyAlbum'...)
     - parameter keyword: the item name
     - parameter completionHandler: the block to run when results
     are found and passed as parameter to it
     */
    public func find<T>(_ what: T.Type,
                        _ keyword: String,
                        completionHandler: @escaping ([T]) -> Void) where T: SpotifySearchItem {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.search,
                                      method: .GET,
                                      parameters: self.searchParameters(for: what.type, keyword),
                                      headers: self.authorizationHeader(with: token))
            { result in
                if  case let .success(data) = result,
                    let results = try? JSONDecoder().decode(SpotifyFindResponse<T>.self,
                                                           from: data).results.items {
                    completionHandler(results)
                }
            }
        }
    }
    
    /**
     Finds the first track on Spotify matching search results for
     - parameter title: the title of the track
     - parameter artist: the artist of the track
     - parameter completionHandler: the handler that is executed with the track as parameter
     */
    public func getTrack(title: String,
                         artist: String,
                         completionHandler: @escaping (SpotifyTrack) -> Void) {
        find(SpotifyTrack.self, "\(title) \(artist)") { results in
            if let track = results.first {
                completionHandler(track)
            }
        }
    }
    
    /**
     Gets the curernt Spotify user's profile
     - parameter completionHandler: the handler that is executed with the user as parameter
     */
    public func myProfile(completionHandler: @escaping (SpotifyUser) -> Void) {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.me,
                                      method: .GET,
                                      headers: self.authorizationHeader(with: token))
            { result in
                if  case let .success(data) = result,
                    let result = try? JSONDecoder().decode(SpotifyUser.self,
                                                           from: data) {
                    completionHandler(result)
                }
            }
        }
    }
    
    // MARK: Authorization
    
    /**
     Retrieves the authorization code with user interaction
     Note: this only opens the browser window with the proper request,
     you then have to manually copy the 'code' from the opened url
     and insert it to get the actual token
     */
    public func authorize() {
        // Only proceed with authorization if we have no token
        guard !hasToken else { return }
        
        if  let application = application,
            let url = SpotifyQuery.authorize.url?.with(parameters: authorizationParameters(for: application)) {
            #if os(OSX)
                #if swift(>=4.0)
                    NSWorkspace.shared.open(url)
                #else
                    NSWorkspace.shared().open(url)
                #endif
            #else
                UIApplication.shared.open(url)
            #endif
        }
    }
    
    /**
     Removes the saved authorization token from the keychain
     */
    public func deauthorize() {
        // Only proceed with deauthorization if we have a token
        guard hasToken else { return }
        
        SpotifyToken.deleteFromKeychain()
        
        // Reset the token
        token = nil
    }
    
    /**
     Retrieves the authorization code after the authentication process has succeded
     and completes token saving.
     - parameter url: the URL with code sent by Spotify after authentication success
     */
    public func saveToken(from url: URL) {
        if  let urlComponents = URLComponents(string: url.absoluteString),
            let queryItems    = urlComponents.queryItems {
            
            // Get "code=" parameter from URL
            let code = queryItems.filter { item in item.name == "code" } .first?.value!
            
            // Send code to SpotifyKit
            if let authorizationCode = code {
                saveToken(from: authorizationCode)
            }
        }
    }
    
    /**
     Retrieves the token from the authorization code and saves it locally
     - parameter authorizationCode: the code received from Spotify redirected uri
     */
    public func saveToken(from authorizationCode: String) {
        guard let application = application else { return }
        
        URLSession.shared.request(SpotifyQuery.token,
                                  method: .POST,
                                  parameters: tokenParameters(for: application,
                                                              from: authorizationCode))
        { result in
            if case let .success(data) = result {
                self.token = self.generateToken(from: data)
                
                // Prints the token for debug
                if let token = self.token {
                    debugPrint(token.details)
                    
                    switch self.tokenSavingMethod {
                    case .preference:
                        token.writeToKeychain()
                    }
                }
            }
        }
        
        
    }
    
    /**
     Generates a token from values provided by the user
     - parameters: the token data
     */
    public func saveToken(accessToken:  String,
                          expiresIn:    Int,
                          refreshToken: String,
                          tokenType:    String) {
        self.token = SpotifyToken(accessToken: accessToken,
                                  expiresIn: expiresIn,
                                  refreshToken: refreshToken,
                                  tokenType: tokenType)
        
        // Prints the token for debug
        if let token = self.token { debugPrint(token.details) }
    }
    
    /**
     Returns if the helper is currently holding a token
     */
    public var hasToken: Bool {
        guard let token = token else { return false }
        
        // Only return true if the token is actually valid
        return token.isValid
    }
    
    /**
     Refreshes the token when expired
     */
    public func refreshToken(completionHandler: @escaping (Bool) -> ()) {
        guard let application = application, let token = self.token else { return }
        
        URLSession.shared.request(SpotifyQuery.token,
                                  method: .POST,
                                  parameters: refreshTokenParameters(from: token),
                                  headers: refreshTokenHeaders(for: application))
        { result in
            if case let .success(data) = result {
                // Refresh current token
                // Only 'accessToken' needs to be changed
                // guard is not really needed here because we checked before
                self.token?.refresh(from: data)
                
                // Prints the token for debug
                if let token = self.token {
                    debugPrint(token.details)
                    
                    // Run completion handler
                    // only after the token has been saved
                    completionHandler(true)
                }
            } else {
                completionHandler(false)
            }
        }
    }
    
    // MARK: User library interaction
    
    /**
     Gets the first saved tracks/albums/playlists in user's library
     - parameter type: .track, .album or .playlist
     - parameter completionHandler: the callback to run, passes the tracks array
     as argument
     // TODO: read more than 20/10 items
     */
    public func library<T>(_ what: T.Type,
                           completionHandler: @escaping ([T]) -> Void) where T: SpotifyLibraryItem {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.libraryUrlFor(what),
                                      method: .GET,
                                      headers: self.authorizationHeader(with: token))
            { result in
                if  case let .success(data) = result,
                    let results = try? JSONDecoder().decode(SpotifyLibraryResponse<T>.self,
                                                           from: data).items {
                    completionHandler(results)
                }
            }
        }
    }
    
    /**
     Saves a track to user's "Your Music" library
     - parameter trackId: the id of the track to save
     - parameter completionHandler: the callback to execute after response,
     brings the saving success as parameter
     */
    public func save(trackId: String,
                     completionHandler: @escaping (Bool) -> Void) {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.libraryUrlFor(SpotifyTrack.self),
                                      method: .PUT,
                                      parameters: self.trackIdsParameters(for: trackId),
                                      headers: self.authorizationHeader(with: token))
            { result in
                if case .success(_) = result {
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            }
        }
    }
    
    /**
     Saves a track to user's "Your Music" library
     - parameter track: the 'SpotifyTrack' object to save
     - parameter completionHandler: the callback to execute after response,
     brings the saving success as parameter
     */
    public func save(track: SpotifyTrack,
                     completionHandler: @escaping (Bool) -> Void) {
        save(trackId: track.id, completionHandler: completionHandler)
    }
    
    /**
     Deletes a track from user's "Your Music" library
     - parameter trackId: the id of the track to save
     - parameter completionHandler: the callback to execute after response,
     brings the deletion success as parameter
     */
    public func delete(trackId: String,
                       completionHandler: @escaping (Bool) -> Void) {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.libraryUrlFor(SpotifyTrack.self),
                                      method: .DELETE,
                                      parameters: self.trackIdsParameters(for: trackId),
                                      headers: self.authorizationHeader(with: token))
            { result in
                if case .success(_) = result {
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            }
                
        }
    }
    
    /**
     Deletes a track from user's "Your Music" library
     - parameter track: the 'SpotifyTrack' object to save
     - parameter completionHandler: the callback to execute after response,
     brings the deletion success as parameter
     */
    public func delete(track: SpotifyTrack,
                       completionHandler: @escaping (Bool) -> Void) {
        delete(trackId: track.id, completionHandler: completionHandler)
    }
    
    /**
     Checks if a track is saved into user's "Your Music" library
     - parameter track: the id of the track to check
     - parameter completionHandler: the callback to execute after response,
     brings 'isSaved' as parameter
     */
    public func isSaved(trackId: String,
                        completionHandler: @escaping (Bool) -> Void) {
        tokenQuery { token in
            URLSession.shared.request(SpotifyQuery.contains,
                                      method: .GET,
                                      parameters: self.trackIdsParameters(for: trackId),
                                      headers: self.authorizationHeader(with: token))
            { result in
                // Sends the 'isSaved' value back to the completion handler
                if  case let .success(data) = result,
                    let results = try? JSONDecoder().decode([Bool].self, from: data),
                    let saved = results.first {
                    completionHandler(saved)
                }
            }
        }
    }
    
    /**
     Checks if a track is saved into user's "Your Music" library
     - parameter track: the 'SpotifyTrack' object to check
     - parameter completionHandler: the callback to execute after response,
     brings 'isSaved' as parameter
     */
    public func isSaved(track: SpotifyTrack,
                        completionHandler: @escaping (Bool) -> Void) {
        isSaved(trackId: track.id, completionHandler: completionHandler)
    }
    
    // MARK: Helper functions
    
    /**
     Builds search query parameters for an element on Spotify
     - return: searchquery parameters
     */
    private func searchParameters(for type: SpotifyItemType,
                                  _ keyword: String) -> HTTPRequestParameters {
        return [SpotifyParameter.name: "\(keyword)*",
                SpotifyParameter.type: type.rawValue]
    }
    
    /**
     Builds authorization parameters
     */
    private func authorizationParameters(for application: SpotifyDeveloperApplication) -> HTTPRequestParameters {
        return [SpotifyParameter.clientId: application.clientId,
                SpotifyParameter.responseType: SpotifyAuthorizationResponseType.code.rawValue,
                SpotifyParameter.redirectUri: application.redirectUri,
                SpotifyParameter.scope: SpotifyScope.string(with: [.readPrivate, .readEmail, .libraryModify, .libraryRead, .playlistRead, .playlistModifyPrivate, .playlistModifyPublic])]
    }
    
    /**
     Builds token parameters
     - return: parameters for token retrieval
     */
    private func tokenParameters(for application: SpotifyDeveloperApplication,
                                 from authorizationCode: String) -> HTTPRequestParameters {
        return [SpotifyParameter.clientId: application.clientId,
                SpotifyParameter.clientSecret: application.clientSecret,
                SpotifyParameter.grantType: SpotifyTokenGrantType.authorizationCode.rawValue,
                SpotifyParameter.code: authorizationCode,
                SpotifyParameter.redirectUri: application.redirectUri]
    }
    
    /**
     Builds token refresh parameters
     - return: parameters for token refresh
     */
    private func refreshTokenParameters(from oldToken: SpotifyToken) -> HTTPRequestParameters {
        return [SpotifyParameter.grantType: SpotifyTokenGrantType.refreshToken.rawValue,
                SpotifyParameter.refreshToken: oldToken.refreshToken]
    }
    
    /**
     Builds the authorization header for token refresh
     - return: authorization header
     */
    private func refreshTokenHeaders(for application: SpotifyDeveloperApplication) -> HTTPRequestHeaders {
        guard let auth = URLSession.authorizationHeader(user: application.clientId, password: application.clientSecret) else { return [:] }
        
        return [auth.key: auth.value]
    }
    
    /**
     Builds the authorization header for user library interactions
     - return: authorization header
     */
    private func authorizationHeader(with token: SpotifyToken) -> HTTPRequestHeaders {
        return [SpotifyHeader.authorization: SpotifyAuthorizationType.bearer.rawValue +
            token.accessToken]
    }
    
    /**
     Builds parameters for saving a track into user's library
     - return: parameters for track saving
     */
    private func trackIdsParameters(for trackId: String) -> HTTPRequestParameters {
        return [SpotifyParameter.ids: trackId]
    }
    
    /**
     Generates a 'SpotifyToken' from a JSON response
     - return: the 'SpotifyToken' object
     */
    private func generateToken(from data: Data) -> SpotifyToken? {
        return try? JSONDecoder().decode(SpotifyToken.self, from: data)
    }
    
    // MARK: Added code to pull relevant information
    
    // Codable for list of playlists
    struct PlaylistsList: Codable {
        let href: String
        let items: [Item]?
        let limit: Int
        let next: JSONNull?
        let offset: Int
        let previous: JSONNull?
        let total: Int
    }
    
    struct Item: Codable {
        let collaborative: Bool
        let externalUrls: ExternalUrls
        let href: String?
        let id: String
        let images: [Image]
        let name: String
        let owner: Owner
        let primaryColor: JSONNull?
        let itemPublic: Bool
        let snapshotID: String
        let tracks: Tracks
        let type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case collaborative
            case externalUrls = "external_urls"
            case href, id, images, name, owner
            case primaryColor = "primary_color"
            case itemPublic = "public"
            case snapshotID = "snapshot_id"
            case tracks, type, uri
        }
    }
    
    struct ExternalUrls: Codable {
        let spotify: String
    }
    
    struct Image: Codable {
        let height: Int
        let url: String
        let width: Int
    }
    
    struct Owner: Codable {
        let displayName: String
        let externalUrls: ExternalUrls
        let href: String
        let id, type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case externalUrls = "external_urls"
            case href, id, type, uri
        }
    }
    
    struct Tracks: Codable {
        let href: String
        let total: Int
    }
    
    class JSONNull: Codable, Hashable {
        
        public static func == (lhs: JSONNull, rhs: JSONNull) -> Bool {
            return true
        }
        
        public var hashValue: Int {
            return 0
        }
        
        public init() {}
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if !container.decodeNil() {
                throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
    
    // End Codeable declare
    
    // Gets list of playlists from user's Spotify account
    public func getListOfPlaylists(completionBlock: @escaping ([(String, String, Int)]) -> Void) -> Void {
        let auth = self.token!.tokenType + " " + self.token!.accessToken
        
        let urlString = "https://api.spotify.com/v1/me/playlists?limit=50"
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(auth, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            
            guard let data = data else {
                print("Data is empty")
                return
            }
            
            let decoder = JSONDecoder()
            
            do {
                let json_response = try decoder.decode(PlaylistsList.self, from: data)
                
                // (playlistName, playlistId, numTracks)
                var playlists = [(String, String, Int)]()
                
                for Item in json_response.items! {
                    playlists.append((Item.name, Item.id, Item.tracks.total))
                }
                
                completionBlock(playlists)
            } catch {
                print(error)
            }
        }
        
        task.resume()
    }
    
    // Create an empty playlist on user's Spotify account
    public func createPlaylist(name: String, completionHandler: @escaping (String) -> Void) {
        let auth = self.token!.tokenType + " " + self.token!.accessToken
        
        // Change eventually to make general for any username
        let url = URL(string: "https://api.spotify.com/v1/users/ec__/playlists")
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"

        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(auth, forHTTPHeaderField: "Authorization")
        
        let json: [String: Any] = ["name": name]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            
            guard data != nil else {
                print("Data is empty")
                return
            }
                        
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    print("Successfully created playlist")
                } else {
                    print("Could not create playlist")
                }
                
                if let location = httpResponse.allHeaderFields["Location"] as? String {
                    let locationComponents = location.components(separatedBy: "/")
                    let newPlaylistID = locationComponents[locationComponents.count - 1]
                    completionHandler(newPlaylistID)
                }
            }
        }
        
        task.resume()
    }
    
    // Get all explicit songs in given playlist
    public func getExplicitTracks(playlistID: String) {
        
    }
    
    // Begin Codeable
    
    struct PlaylistTracks: Codable {
        let href: String?
        let items: [Item2]?
        let limit: Int?
        let next: JSONNull?
        let offset: Int?
        let previous: JSONNull?
        let total: Int?
    }
    
    struct Item2: Codable {
        let addedAt: String
        let addedBy: AddedBy
        let isLocal: Bool
        let track: Track?
        
        enum CodingKeys: String, CodingKey {
            case addedAt = "added_at"
            case addedBy = "added_by"
            case isLocal = "is_local"
            case track
        }
    }
    
    struct AddedBy: Codable {
        let externalUrls: ExternalUrls2
        let href: String?
        let id, type, uri: String
        let name: String?
        
        enum CodingKeys: String, CodingKey {
            case externalUrls = "external_urls"
            case href, id, type, uri, name
        }
    }
    
    struct ExternalUrls2: Codable {
        let spotify: String
    }
    
    struct Track: Codable {
        let album: Album
        let artists: [AddedBy]
        let availableMarkets: [String]
        let discNumber, durationMS: Int
        let explicit: Bool
        let externalIDS: ExternalIDS
        let externalUrls: ExternalUrls2
        let href: String?
        let id, name: String
        let popularity: Int
        let previewURL: String?
        let trackNumber: Int
        let type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case album, artists
            case availableMarkets = "available_markets"
            case discNumber = "disc_number"
            case durationMS = "duration_ms"
            case explicit
            case externalIDS = "external_ids"
            case externalUrls = "external_urls"
            case href, id, name, popularity
            case previewURL = "preview_url"
            case trackNumber = "track_number"
            case type, uri
        }
    }
    
    struct Album: Codable {
        let albumType: String
        let artists: [AddedBy]
        let availableMarkets: [String]
        let externalUrls: ExternalUrls2
        let href: String?
        let id: String
        let images: [Image2]
        let name, type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case albumType = "album_type"
            case artists
            case availableMarkets = "available_markets"
            case externalUrls = "external_urls"
            case href, id, images, name, type, uri
        }
    }
    
    struct Image2: Codable {
        let height: Int
        let url: String
        let width: Int
    }
    
    struct ExternalIDS: Codable {
        let isrc: String
    }
    
    // End Codeable
    
    // Start Search Codeable
    struct Search: Codable {
        let tracks: Tracks3
    }
    
    struct Tracks3: Codable {
        let href: String
        let items: [Item3]
        let limit: Int
        let next: String?
        let offset: Int
        let previous: JSONNull?
        let total: Int
    }
    
    struct Item3: Codable {
        let album: Album3
        let artists: [Artist3]
        let availableMarkets: [String]
        let discNumber, durationMS: Int
        let explicit: Bool
        let externalIDS: ExternalIDS3
        let externalUrls: ExternalUrls3
        let href: String
        let id: String
        let isLocal: Bool
        let name: String
        let popularity: Int
        let previewURL: JSONNull?
        let trackNumber: Int
        let type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case album, artists
            case availableMarkets = "available_markets"
            case discNumber = "disc_number"
            case durationMS = "duration_ms"
            case explicit
            case externalIDS = "external_ids"
            case externalUrls = "external_urls"
            case href, id
            case isLocal = "is_local"
            case name, popularity
            case previewURL = "preview_url"
            case trackNumber = "track_number"
            case type, uri
        }
    }
    
    struct Album3: Codable {
        let albumType: String
        let artists: [Artist3]
        let availableMarkets: [String]
        let externalUrls: ExternalUrls3
        let href: String
        let id: String
        let images: [Image3]
        let name, releaseDate, releaseDatePrecision: String
        let totalTracks: Int
        let type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case albumType = "album_type"
            case artists
            case availableMarkets = "available_markets"
            case externalUrls = "external_urls"
            case href, id, images, name
            case releaseDate = "release_date"
            case releaseDatePrecision = "release_date_precision"
            case totalTracks = "total_tracks"
            case type, uri
        }
    }
    
    struct Artist3: Codable {
        let externalUrls: ExternalUrls3
        let href: String
        let id, name, type, uri: String
        
        enum CodingKeys: String, CodingKey {
            case externalUrls = "external_urls"
            case href, id, name, type, uri
        }
    }
    
    struct ExternalUrls3: Codable {
        let spotify: String
    }
    
    struct Image3: Codable {
        let height: Int
        let url: String
        let width: Int
    }
    
    struct ExternalIDS3: Codable {
        let isrc: String
    }

    
    // End Search Codeable
    
    public func getAllTracksInPlaylist(playlistID: String, completionBlock: @escaping ([(String, String, String, String, String, Bool)]) -> Void) -> Void {
        let auth = self.token!.tokenType + " " + self.token!.accessToken
        
        
        let urlString = "https://api.spotify.com/v1/playlists/" + playlistID + "/tracks"
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"

        request.addValue(auth, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            
            guard let data = data else {
                print("Data is empty")
                return
            }
            
            let decoder = JSONDecoder()
            
            do {
                let json_response = try decoder.decode(PlaylistTracks.self, from: data)
                
                var tracks = [(String, String, String, String, String, Bool)]()
            
                for Track in json_response.items! {
                    // (trackName, trackID, artists, artworkImage, trackURI, explicit)
                    var track: (String, String, String, String, String, Bool)
                    
                    let trackName = Track.track?.name
                    track.0 = trackName!
                    
                    let trackID = Track.track?.id
                    track.1 = trackID!
                    
                    var artistsString = ""
                    
                    let numArtists = Track.track?.artists.count
                    var numArtistsInString = 0
                    for Artist in (Track.track?.artists)! {
                        numArtistsInString += 1
                        artistsString += Artist.name!
                        if numArtistsInString != numArtists {
                            artistsString += ", "
                        }
                    }
                    track.2 = artistsString
                    
                    
                    let image = Track.track?.album.images[0]
                    track.3 = image!.url
                    
                    let trackURI = Track.track?.uri
                    track.4 = trackURI!
                    
                    let explicit = Track.track?.explicit
                    track.5 = explicit!
                    
                    tracks.append(track)
                }
                
                completionBlock(tracks)
            } catch {
                print(error)
            }
        }
        
        task.resume()
    }
    
    public func addTracksToPlaylist(playlistID: String, uris: [String]) {
        let auth = self.token!.tokenType + " " + self.token!.accessToken
    
        var uriString = "uris=" + uris.joined(separator: ",")
        uriString = uriString.replacingOccurrences(of: ":", with: "%3A")
        
        let urlString = "https://api.spotify.com/v1/playlists/" + playlistID + "/tracks?" + uriString
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        
        request.addValue(auth, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            
            guard data != nil else {
                print("Data is empty")
                return
            }
        }
        
        task.resume()
    }
    
    // Search for clean version of given song
    public func searchForCleanVersion(trackName: String, trackArtists: String) {
        let auth = self.token!.tokenType + " " + self.token!.accessToken

        var trackNameURLEncoded = trackName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        var trackArtistsURLEncoded = trackArtists.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        trackNameURLEncoded = trackNameURLEncoded.replacingOccurrences(of: ",", with: "%2C")
        trackArtistsURLEncoded = trackArtistsURLEncoded.replacingOccurrences(of: ",", with: "%2C")
        
        let urlString = "https://api.spotify.com/v1/search?" + "q=track:" + trackNameURLEncoded + "%20artist:" + trackArtistsURLEncoded + "&type=track"
        
        let url = URL(string: urlString)

        var request = URLRequest(url: url!)
        request.httpMethod = "GET"

        request.addValue(auth, forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }

            guard data != nil else {
                print("Data is empty")
                return
            }
            
            let decoder = JSONDecoder()
            
            // DEV
//            let str = String(decoding: data!, as: UTF8.self)
//            print(str)
            // DEV
            
            do {
                let json_response = try decoder.decode(Search.self, from: data!)
                
                for Item3 in json_response.tracks.items {
                    print(Item3.name, Item3.explicit)
                    if Item3.name == trackName && !Item3.explicit {
                        var testArtistsString = ""
                        for Artist3 in Item3.artists {
                            testArtistsString += Artist3.name + " "
                        }
                        testArtistsString = testArtistsString.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
                        
                        if testArtistsString == trackArtists.replacingOccurrences(of: ", ", with: " ") {
                            print("FOUND TRACK!")
                            break
                        }
                    }
                }
            } catch {
                print("Error decoding search results")
            }
        }

        task.resume()
    }
    
    
    
    // Refreshes the token if needed
    public func refreshTokenIfNeeded() {
        if hasToken {
            if (token?.isExpired)! {
                // If the token is expired, refresh it first
                // Then try repeating the operation
                refreshToken { refreshed in
                    if refreshed {
                        print("token refreshed")
                    }
                }
            }
        } else {
            authorize()
        }
    }
}

extension Dictionary {
    func percentEscaped() -> String {
        return map { (key, value) in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
            }
            .joined(separator: "&")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
