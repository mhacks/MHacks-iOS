//
//  APIManager.swift
//  MHacks
//
//  Created by Manav Gabhawala on 12/14/15.
//  Copyright © 2015 MHacks. All rights reserved.
//

import Foundation

enum HTTPMethod : String {
	case get = "GET"
	case post = "POST"
	case put = "PUT"
	case patch = "PATCH"
	case delete = "DELETE"
}

enum Response<T> {
	case value(T)
	case error(String)
}

private let archiveLocation = container.appendingPathComponent("archive.plist")

final class APIManager
{
	#if DEBUG
		private static let baseURL = URL(string: "https://staging.mhacks.org")!
	#else
		private static let baseURL = URL(string: "https://mhacks.org")!
	#endif
	
	// MARK: - Initializers
	
	// private so that nobody else can access this, and shared is the only hook into the APIManager
	private init() { }
	
	/// The main hook into the `APIManager` class. Use this singleton to make all requests and fetch the single source of truth about the state of all data.
	static var shared: APIManager = {
		let manager = APIManager()
		manager.initialize()
		return manager
	}()
	
	fileprivate var authenticator : Authenticator?
	
	// MARK: - User related readonly attributes
	
	/// Encapsulates user information
	struct UserInfo: CustomStringConvertible, CustomDebugStringConvertible
	{
		/// The ID for the user. Can be used to uniquely identify a user quickly, especially on the backend
		var userID: String
		
		/// The user's email address
		var email: String
		
		/// The user's full name, ready for display!
		var name: String
		
		/// The school the user goes to, this is optional because the backend may not *always* send it over
		/// recover gently when it is nil (although rare)
		var school: String?
		
		var description: String { return name }
		var debugDescription: String { return "UserInfo for \(name) with ID: \(userID)" }
	}

	/// Encapsulates the current state of the user i.e. logged in or not and associates user info with the logged in state
	///
	/// - LoggedIn:  When logged in you also have access to the user info struct as the associated data
	/// - LoggedOut: Just a regular LoggedOut state
	enum UserState
	{
		case LoggedIn(UserInfo)
		case LoggedOut
	}
	
	var canPostAnnouncements: Bool {
		return authenticator?.canPostAnnouncements ?? false
	}
	var canEditAnnouncements : Bool {
		return authenticator?.canEditAnnouncements ?? false
	}
	var canScanUserCode: Bool {
		return authenticator?.canPerformScan ?? false
	}
	
	
	/// Updates the user profile by updating the user's information and their privileges.
	///
	/// - parameter completion: If you are interested on being notified of changes.
	func updateUserProfile(_ completion: CoalescedCallbacks.Callback? = nil)
	{
		guard authenticator != nil
		else {
			completion?(false)
			return
		}
		
		taskWithRoute("/v1/profile/") { response in
			switch response
			{
			case .value(let newData):
				guard let newAuthenticator = Authenticator(newData)
				else {
					completion?(false)
					return
				}
				if newAuthenticator.canEditAnnouncements != self.authenticator?.canEditAnnouncements
				{
					// Invalidate the cache for announcements if the user's permissions changed
					// This will effectively download all announcements again
					self.announcements.empty()
				}
				self.authenticator = newAuthenticator
				completion?(true)
			case .error(let errorMessage):
				NotificationCenter.default.post(name: APIManager.FailureNotification, object: errorMessage)
				completion?(false)
			}
		}
	}
	
	/// This can fetch the current state for the user along with their information if they are logged in.
	/// - Warning: Querying for the user state is not trivial therefore, do so only when absolutely required and store the result in a variable rather than querying this field every time. That said, it's not **that** expensive, so use it liberally where desired but cache the result instead of querying.
	var userState: UserState {
		guard let authenticator = authenticator
		else { return .LoggedOut }
		return .LoggedIn(UserInfo(userID: authenticator.username, email: authenticator.username, name: authenticator.name, school: authenticator.school))
	}
	/// A quick helper if you are only interested in the logged in/logged out state and not the associated data
	var loggedIn: Bool {
		return authenticator != nil
	}
	
	// MARK: - APNS Token
	fileprivate static let APNSTokenKey = "registration_id"
	fileprivate static let APNSPreferenceKey = "name"
	fileprivate func getTokenAndPreference(newPreference: Int?) -> (String, Int)?
	{
		guard let deviceID = defaults.string(forKey: remoteNotificationTokenKey)
		else {
			return nil
		}
		var preferenceToSend: Int
		if let preference = newPreference
		{
			preferenceToSend = preference
		}
		else
		{
			preferenceToSend = defaults.integer(forKey: remoteNotificationPreferencesKey)
			if preferenceToSend == 0
			{
				preferenceToSend = 63
			}
		}
		return (deviceID, preferenceToSend)
	}
	
	/// Create/Update the APNS Token for the user so that they can recieve push notifications
	///
	/// - parameter preference: The user's preference. Defaults to 63 which means all. Will be in UserDefaults with the key `remoteNotificationPreferencesKey`
	/// - parameter completion: An optional completion block if you are interested in the success of the request.
	func updateAPNSToken(preference: Int? = nil, completion: CoalescedCallbacks.Callback? = nil)
	{
		guard let (deviceID, preference) = getTokenAndPreference(newPreference: preference)
		else {
			completion?(false)
			return
		}
		
		taskWithRoute("/v1/push_notifications/apns/", parameters: [APIManager.APNSTokenKey: deviceID, APIManager.APNSPreferenceKey: "\(preference)"], usingHTTPMethod: .post) { response in
			switch response {
			case .value(let json):
				guard let token = json["registration_id"] as? String, token == deviceID
				else {
					completion?(false)
					return
				}
				guard let preferenceString = json[APIManager.APNSPreferenceKey] as? String, let preference = Int(preferenceString)
				else {
					completion?(false)
					return
				}
				defaults.set(preference, forKey: remoteNotificationPreferencesKey)
				completion?(true)
			case .error(let errorMessage):
				NotificationCenter.default.post(name: APIManager.FailureNotification, object: errorMessage)
				completion?(false)
			}
		}
	}
	
	// MARK: - Announcements
	
	/// The "array" of announcements
	let announcements = MHacksArray<Announcement>()
	
	///	Updates the announcements and posts a notification on completion.
	///	- parameter callback:	The completion block, true on success, false on failure.
	func updateAnnouncements(_ callback: CoalescedCallbacks.Callback? = nil) {
		updateUsing(route: "/v1/announcements/", notificationName: APIManager.AnnouncementsUpdatedNotification, callback: callback, existingObject: announcements)
	}
	
	/// Update/Posts an announcment.
	///
	/// - parameter announcement: The announcement struct with all the fields filled as required
	/// - parameter method:       .post to create a new announcement, .put to update an existing one
	/// - parameter completion:   The completion block, true on success, false on failure.
	///
	/// - note: Do *not* update the UI automatically to compensate for this change. The MHacksArray will be updated separately and will post its notification.
	func updateAnnouncement(_ announcement: Announcement, usingMethod method: HTTPMethod, completion: CoalescedCallbacks.Callback? = nil)
	{
		let route = method == .put ? "/v1/announcements/\(announcement.ID)" : "/v1/announcements"
		taskWithRoute(route, parameters: announcement.toSerializedRepresentation() as? [String: Any] ?? [:], usingHTTPMethod: method) { response in
			switch response
			{
			case .value(_):
				completion?(true)
				self.updateAnnouncements()
			case .error(let errorMessage):
				NotificationCenter.default.post(name: APIManager.FailureNotification, object: errorMessage)
				completion?(false)
			}
		}
	}
	
	/// Deletes an announcement
	///
	/// - parameter announcementIndex: The announcement to delete
	/// - parameter completion:        The completion block, true on success, false on failure.
	///
	/// - note: Do *not* update the UI automatically to compensate for this change. The MHacksArray will be updated separately and will post its notification.
	func deleteAnnouncement(_ announcement: Announcement, completion: CoalescedCallbacks.Callback? = nil)
	{
		taskWithRoute("/v1/announcements/\(announcement.ID)", usingHTTPMethod: .delete) { response in
			switch response
			{
			case .value(_):
				completion?(true)
				self.updateAnnouncements()
			case .error(let errorMessage):
				NotificationCenter.default.post(name: APIManager.FailureNotification, object: errorMessage)
				completion?(false)
			}
		}
	}
	
	
	// MARK: - Countdown
	/// The readonly countdown object. This is a reference type
	private(set) var countdown = Countdown()
	
	/// Updates the countdown, with an optional callback
	func updateCountdown(_ callback: CoalescedCallbacks.Callback? = nil)
	{
		updateUsing(route: "/v1/countdown/", notificationName: APIManager.CountdownUpdatedNotification, callback: callback, existingObject: countdown)
	}
	
	// MARK: - Events
	fileprivate let events = MHacksArray<Event>()
	private(set) var eventsOrganizer = EventOrganizer(events: MHacksArray<Event>())
	func updateEvents(_ callback: CoalescedCallbacks.Callback? = nil) {
		updateLocations { succeeded in
			guard succeeded
			else
			{
				if let callback = callback
				{
					self.events.coalescer.registerCallback(callback)
				}
				self.events.coalescer.fire(false)
				return
			}
			self.updateUsing(route: "/v1/events/", notificationName: APIManager.EventsUpdatedNotification, callback: callback, existingObject: self.events)
			{ _ in
				self.eventsOrganizer = EventOrganizer(events: self.events)
			}
		}
	}
	
	// MARK: - Location
	let locations = MHacksArray<Location>()
	func updateLocations(_ callback: CoalescedCallbacks.Callback? = nil) {
		updateUsing(route: "/v1/locations/", notificationName: APIManager.LocationsUpdatedNotification, callback: callback, existingObject: locations)
	}
	
	
	// MARK: - Map
	private(set) var map = Map()
	func updateMap(_ callback: CoalescedCallbacks.Callback? = nil) {
//		updateUsing(route: "/v1/map/", notificationKey: .MapUpdated, callback: callback, existingObject: map)
		// FIXME: Map needs to be reimplemented to support floors
		
//		updateGenerically("/v1/map/", notification: .MapUpdated, semaphoreGuard: mapSemaphore, coalecser: mapCallbacks, callback: callback) {(result: JSONWrapper) in
//			// FIXME: This is a redundancy mess, cleanup once backend works better
//			var newJSON = result.JSON
//			let completion = { () -> Bool in
//				guard let map = Map(serialized: Serialized(JSON: newJSON)) , map != self.map
//				else {
//					return false
//				}
//				self.map = map
//				return true
//			}
//			guard let URLString = result[Map.imageURLKey] as? String
//			else {
//				return false
//			}
//			guard self.map?.imageURL != URLString
//			else {
//				newJSON[Map.fileLocationKey] = self.map?.fileLocation
//				return completion()
//			}
//			guard let URL = URL(string: URLString)
//			else {
//				return false
//			}
//			let downloadTask = URLSession.shared.downloadTask(with: URL, completionHandler: { downloadedImage, response, error in
//				guard error == nil, let downloaded = downloadedImage
//				else {
//					guard completion()
//					else {
//						NotificationCenter.default.post(.Failure, object: (error?.localizedDescription ?? "Could not save map") as NSString)
//						return
//					}
//					NotificationCenter.default.post(.MapUpdated)
//					return
//				}
//				do {
//					let fileURL = container.appendingPathComponent("map.png")
//					let _ = try? FileManager.default.removeItem(at: fileURL)
//					try FileManager.default.moveItem(at: downloaded, to: fileURL)
//					newJSON[Map.fileLocationKey] = fileURL.absoluteString
//					guard completion()
//					else {
//						return
//					}
//					NotificationCenter.default.post(.MapUpdated, object: self)
//				}
//				catch {
//					NotificationCenter.default.post(.Failure, object: (error as NSError).localizedDescription)
//				}
//			})
//			downloadTask.resume()
//			return false
//		}
	}
	
	// MARK: - PKPass
	
	/// Do *not* use this method directly. Instead see fetchPass()
	func fetchPKPassAsData(_ callback: @escaping (Response<Data>) -> Void)
	{
		guard loggedIn
		else {
			callback(.error("Cannot fetch pass while not logged in"))
			return
		}
		taskWithRoute("/v1/apple_pass/") { response in
			switch response
			{
			case .value(let json):
				guard let encodedPassInformation = json["apple_pass"] as? String, let passData = Data(base64Encoded: encodedPassInformation, options: .ignoreUnknownCharacters)
				else {
					callback(.error("Invalid pass downloaded. Try again"))
					return
				}
				callback(.value(passData))
			case .error(let message):
				callback(.error(message))
			}
		}
	}
	
	// MARK: - ScanEvent
	let scanEvents = MHacksArray<ScanEvent>()
	func updateScanEvents(_ callback: CoalescedCallbacks.Callback? = nil)
	{
		updateUsing(route: "/v1/scan_events/", notificationName: APIManager.ScanEventsUpdatedNotification, callback: callback, existingObject: scanEvents)
	}
	
	// MARK: - Perform Scan
	
	
	/// A method to "do" a scan, i.e. after reading in a user's data
	///
	/// - parameter userDataScanned: The user's data that was scanned from the barcode. This can and should be opaque to you.
	/// - parameter scanEvent:       The scan event you want to scan for
	/// - parameter readOnlyPeek:    Whether the scan should be readonly, i.e. not actually perform the scan but check what the result of the scan would be. Pass false if you want the scan to actually be saved to the server
	/// - parameter callback:        A callback after the server responds, the parameters are a boolean indicating success of the scan event as well as additionalData associated with the scan. This is scan event specific so you must parse it manually as you see fit. Note additionalData may still be nil even if succeeded is true if there is no additional data for that particular scan event
	func performScan(userDataScanned: String, scanEvent: ScanEvent, readOnlyPeek: Bool, _ callback: @escaping (_ succeeded: Bool, _ additionalData: [ScannedDataField]) -> Void)
	{
		taskWithRoute("/v1/perform_scan/", parameters: ["user_id": userDataScanned, "scan_event": scanEvent.ID], usingHTTPMethod: readOnlyPeek ? .get : .post) { response in
			switch response
			{
			case .value(let json):
				guard let succeeded = json["scanned"] as? Bool, succeeded, let serializedItems = json["data"] as? [SerializedRepresentation]
				else { return callback(false, []) }
				let scannedDataFields = serializedItems.flatMap { ScannedDataField($0) }
				callback(succeeded, scannedDataFields)
			case .error(let errorMessage):
				callback(false, [])
				NotificationCenter.default.post(name: APIManager.FailureNotification, object: errorMessage)
			}
		}
	}
	
	// MARK: - Helpers
	
	fileprivate func createRequestForRoute(_ route: String, parameters: [String: Any] = [String: Any](), usingHTTPMethod method: HTTPMethod = .get) -> URLRequest
	{
		assert(!route.isEmpty, "Route should never be empty!")
		var urlComponents = URLComponents(url: APIManager.baseURL.appendingPathComponent(route), resolvingAgainstBaseURL: false)!
		
		let formData = parameters.reduce("", { $0 + "\($1.0)=\($1.1)&" })
		if (method == .get)
		{
			urlComponents.query = formData
		}
		
		var mutableRequest = URLRequest(url: urlComponents.url!)
		mutableRequest.httpMethod = method.rawValue
		authenticator?.addAuthorizationHeader(&mutableRequest)
		if method == .post || method == .put || method == .patch {
			mutableRequest.httpBody = formData.substring(to: formData.index(before: formData.endIndex)).data(using: .utf8)
		}
		return mutableRequest
	}
	
	private func taskWithRoute(_ route: String, parameters: [String: Any] = [String: Any](), usingHTTPMethod method: HTTPMethod = .get, completion: @escaping (Response<[String: Any]>) -> Void)
	{
		let request = createRequestForRoute(route, parameters: parameters, usingHTTPMethod: method)
		#if DEBUG
			print(request.url!)
		#endif
		showNetworkIndicator()
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			
			defer { self.hideNetworkIndicator() }
			
			let statusCode = (response as? HTTPURLResponse)?.statusCode
			guard statusCode != 403 && statusCode != 401
			else {
				if self.loggedIn
				{
					completion(.error("Permission denied!"))
				}
				else
				{
					completion(.error("Authentication failed. Please login."))
				}
				NotificationCenter.default.post(name: APIManager.LoginStateChangedNotification, object: self)
				return
			}
			
			guard error == nil
			else {
				// The fetch failed because of a networking error other than authentication
				completion(.error(error!.localizedDescription))
				return
			}
			guard method != .delete
			else {
				completion(.value([:]))
				return
			}
			guard let data = data, let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []), let json = jsonObject as? [String: Any]
			else {
				assertionFailure("Deserialization should never fail. We recover silently in production builds")
				completion(.error("Deserialization failed"))
				return
			}
			
			guard statusCode == 200 || statusCode == 201
			else {
				let errorMessage = json["detail"] as? String ?? "Unknown error"
				completion(.error(errorMessage))
				return
			}
			
			completion(.value(json))
		}
		task.resume()
	}
	
	private func updateUsing<Object: Serializable>(route: String, notificationName: Notification.Name, callback: CoalescedCallbacks.Callback?, existingObject: Object, completion: CoalescedCallbacks.Callback? = nil) {
		if let callback = callback {
			existingObject.coalescer.registerCallback(callback)
		}
		
		guard existingObject.semaphoreGuard.wait(timeout: DispatchTime.now()) != .timedOut
		else {
			return
		}
		
		taskWithRoute(route, parameters: existingObject.sinceDictionary) { result in
			var errorMessage: String? = nil
			var updated = false
			defer {
				completion?(updated)
				if updated
				{
					NotificationCenter.default.post(name: notificationName, object: self)
				}
				if let error = errorMessage
				{
					NotificationCenter.default.post(name: APIManager.FailureNotification, object: errorMessage)
				}
				existingObject.coalescer.fire(errorMessage == nil)
				existingObject.semaphoreGuard.signal()
			}
			switch result
			{
			case .value(let json):
				guard existingObject.updateWith(json)
					else {
						return
				}
				updated = true
			case .error(let errorString):
				errorMessage = errorString
			}
		}
	}
	
	// MARK: - Archiving
	
	private func initialize() {
		DispatchQueue.global(qos: .userInitiated).async {
			guard let data = try? Data(contentsOf: archiveLocation)
			else {
				return
			}
			
			func updateSerialized(_ serializedObject: Serializable, using representation: NSDictionary, notificationName: Notification.Name, successfulUpdate: (() -> Void)? = nil) {
				serializedObject.semaphoreGuard.wait()
				defer { serializedObject.semaphoreGuard.signal() }
				guard let serialzedRepresentation = representation as? SerializedRepresentation
					else { return }
				if serializedObject.updateWith(serialzedRepresentation) {
					successfulUpdate?()
					NotificationCenter.default.post(name: notificationName, object: self)
				}
			}
			
			if let obj = NSKeyedUnarchiver.unarchiveObject(with: data) as? APIManagerSerializer {
				// Move everything over
				self.authenticator = Authenticator(obj.authenticator as? SerializedRepresentation)
				updateSerialized(self.countdown, using: obj.countdown, notificationName: APIManager.CountdownUpdatedNotification)
				updateSerialized(self.announcements, using: obj.announcements, notificationName: APIManager.AnnouncementsUpdatedNotification)
				updateSerialized(self.locations, using: obj.locations, notificationName: APIManager.LocationsUpdatedNotification)
				updateSerialized(self.map, using: obj.map, notificationName: APIManager.MapUpdatedNotification)
				updateSerialized(self.scanEvents, using: obj.scanEvents, notificationName: APIManager.ScanEventsUpdatedNotification)
				updateSerialized(self.events, using: obj.events, notificationName: APIManager.EventsUpdatedNotification) {
					self.eventsOrganizer = EventOrganizer(events: self.events)
				}
			}
		}
	}
	func archive() {
		guard let serializer = APIManagerSerializer(manager: self)
		else { return }
		
		do {
			let reachable = try? archiveLocation.checkResourceIsReachable()
			if reachable == nil || !(reachable!) {
				try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true, attributes: nil)
			}
			let data = NSKeyedArchiver.archivedData(withRootObject: serializer)
			try data.write(to: archiveLocation)
		}
		catch {
			#if DEBUG
				print("Cache write failed: \(error)")
			#endif
			// Even though the cache write failed, we don't want to do anything that will disrupt
			// the user's workflow here. Even though its slightly more expensive we can always redownload the content.
		}
	}
}

// MARK: - Authentication and User Stuff
extension APIManager {
	func loginWithUsername(_ username: String, password: String, completion: @escaping (Response<Bool>) -> Void) {
		guard !loggedIn
		else {
			completion(.value(true))
			return
		}
		var parameters: [String: Any] = ["username": username, "password": password]
		if let (apnsToken, preference) = getTokenAndPreference(newPreference: nil)
		{
			parameters["is_gcm"] = false
			parameters[APIManager.APNSTokenKey] = apnsToken
			parameters[APIManager.APNSPreferenceKey] = "\(preference)"
		}
		
		let request = createRequestForRoute("/v1/login/", parameters: parameters, usingHTTPMethod: .post)
		showNetworkIndicator()
		
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			defer { self.hideNetworkIndicator() }
			guard error == nil
			else {
				// The fetch failed because of a networking error
				completion(.error(error!.localizedDescription))
				return
			}
			guard let unwrappedJSON = try? JSONSerialization.jsonObject(with: data ?? Data(), options: []), let JSON = unwrappedJSON as? [String: Any]
			else {
				assertionFailure("Deserialization should never fail. We recover silently in production builds")
				completion(.error("Deserialization failed"))
				return
			}

			guard let authToken = JSON["token"] as? String, let userInfo = JSON["user"] as? [String: Any], let authenticator = Authenticator(userInfo, authenticationToken: authToken)
			else
			{
				completion(.value(false))
				return
			}
			
			self.authenticator = authenticator
			completion(.value(true))
			DispatchQueue.global(qos: .background).async {
				self.archive()
			}
			NotificationCenter.default.post(name: APIManager.LoginStateChangedNotification, object: self)
		}
		task.resume()
	}
	func logout() {
		authenticator?.destroyToken()
		authenticator = nil
		NotificationCenter.default.post(name: APIManager.LoginStateChangedNotification, object: self)
		updateAPNSToken()
	}
	
	// MARK: - Private implmentation details of user auth

	/// This class should encapsulate everything about the user and save all of it
	/// The implementation used here is pretty secure so there's noting to worry about
	fileprivate struct Authenticator: SerializableElement {
		
		let username: String
		let name: String
		let school: String?
		let canPostAnnouncements: Bool
		let canEditAnnouncements: Bool
		let canPerformScan: Bool
		
		private let authenticationToken: String
		
		private static let authTokenKey = "MHacksAuthenticationToken"
		private static let usernameKey = "email"
		private static let nameKey = "name"
		private static let schoolKey = "school"
		private static let canPostAnnouncementsKey = "can_post_announcements"
		private static let canEditAnnouncementsKey = "can_edit_announcements"
		private static let canPerformScanKey = "can_perform_scan"
		
		init(authToken: String, username: String, name: String, school: String?,
		     canPostAnnouncements: Bool, canEditAnnouncements: Bool, canPerformScan: Bool) {
			self.authenticationToken = authToken
			self.username = username
			self.name = name
			self.school = school
			self.canPostAnnouncements = canPostAnnouncements
			self.canEditAnnouncements = canEditAnnouncements
			self.canPerformScan = canPerformScan
			NotificationCenter.default.post(name: APIManager.UserProfileUpdatedNotification, object: self)
		}
		
		func addAuthorizationHeader(_ request: inout URLRequest) {
			request.addValue("Token \(authenticationToken)", forHTTPHeaderField: "Authorization")
		}
		
		// MARK: Authenticator Archiving
		
		init?(_ serializedRepresentation: SerializedRepresentation) {
			guard let username = serializedRepresentation[Authenticator.usernameKey] as? String, let name = serializedRepresentation[Authenticator.nameKey] as? String
			else {
				return nil
			}
			guard let authToken = KeychainWrapper.shared.string(forKey: username)
			else {
				return nil
			}
			
			self.init(authToken: authToken, username: username, name: name, school: serializedRepresentation[Authenticator.schoolKey] as? String, canPostAnnouncements: serializedRepresentation[Authenticator.canPostAnnouncementsKey] as? Bool ?? false, canEditAnnouncements: serializedRepresentation[Authenticator.canEditAnnouncementsKey] as? Bool ?? false, canPerformScan: serializedRepresentation[Authenticator.canPerformScanKey] as? Bool ?? false)
		}
		
		init?(_ serializedRepresentation: SerializedRepresentation, authenticationToken: String) {
			guard let username = serializedRepresentation[Authenticator.usernameKey] as? String, KeychainWrapper.shared.set(authenticationToken, forKey: username)
				else { return nil }
			self.init(serializedRepresentation)
		}
		
		func toSerializedRepresentation() -> NSDictionary {
			_ = KeychainWrapper.shared.set(authenticationToken, forKey: username)
			var dict: [String : Any] = [Authenticator.usernameKey: username, Authenticator.nameKey: name, Authenticator.canPostAnnouncementsKey: canPostAnnouncements, Authenticator.canEditAnnouncementsKey: canEditAnnouncements, Authenticator.canPerformScanKey: canPerformScan]
			if let school = school
			{
				dict[Authenticator.schoolKey] = school
			}
			return dict as NSDictionary
		}
		func destroyToken() {
			_ = KeychainWrapper.shared.remove(key: username)
		}
	}
}

// MARK: - Notification Keys
extension APIManager
{
	static let LoginStateChangedNotification = Notification.Name("LoginStateChanged")
	static let AnnouncementsUpdatedNotification = Notification.Name("AnnouncementsUpdated")
	static let CountdownUpdatedNotification = Notification.Name("CountdownUpdated")
	static let EventsUpdatedNotification = Notification.Name("EventsUpdated")
	static let LocationsUpdatedNotification = Notification.Name("LocationsUpdated")
	static let MapUpdatedNotification = Notification.Name("MapUpdated")
	static let ScanEventsUpdatedNotification = Notification.Name("ScanEventsUpdated")
	static let UserProfileUpdatedNotification = Notification.Name("UserProfileUpdated")
	static let FailureNotification = Notification.Name("Failure")
}

final private class APIManagerSerializer: NSObject, NSCoding {
	let authenticator: NSDictionary
	let countdown: NSDictionary
	let announcements: NSDictionary
	let locations: NSDictionary
	let events: NSDictionary
	let map: NSDictionary
	let scanEvents: NSDictionary
	
	private static let authenticatorKey = "authenticator"
	private static let countdownKey = "countdown"
	private static let announcementsKey = "announcements"
	private static let locationsKey = "locations"
	private static let eventsKey = "events"
	private static let mapKey = "map"
	private static let scanEventsKey = "scan_events"
	
	init?(coder aDecoder: NSCoder) {
		guard let countdown = aDecoder.decodeObject(forKey: APIManagerSerializer.authenticatorKey) as? NSDictionary, let announcements = aDecoder.decodeObject(forKey: APIManagerSerializer.announcementsKey) as? NSDictionary, let locations = aDecoder.decodeObject(forKey: APIManagerSerializer.locationsKey) as? NSDictionary, let events = aDecoder.decodeObject(forKey: APIManagerSerializer.eventsKey) as? NSDictionary, let map = aDecoder.decodeObject(forKey: APIManagerSerializer.mapKey) as? NSDictionary, let scanEvents = aDecoder.decodeObject(forKey: APIManagerSerializer.scanEventsKey) as? NSDictionary
			else { return nil }
		
		self.authenticator = aDecoder.decodeObject(forKey: APIManagerSerializer.authenticatorKey) as? NSDictionary ?? NSDictionary()
		self.countdown = countdown
		self.announcements = announcements
		self.locations = locations
		self.events = events
		self.map = map
		self.scanEvents = scanEvents
	}
	
	init?(manager: APIManager) {
		self.authenticator = manager.authenticator?.toSerializedRepresentation() ?? NSDictionary()
		self.countdown = manager.countdown.toSerializedRepresentation()
		self.announcements = manager.announcements.toSerializedRepresentation()
		self.locations = manager.locations.toSerializedRepresentation()
		self.events = manager.events.toSerializedRepresentation()
		self.map = manager.map.toSerializedRepresentation()
		self.scanEvents = manager.scanEvents.toSerializedRepresentation()
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(authenticator, forKey: APIManagerSerializer.authenticatorKey)
		aCoder.encode(countdown, forKey: APIManagerSerializer.countdownKey)
		aCoder.encode(announcements, forKey: APIManagerSerializer.announcementsKey)
		aCoder.encode(locations, forKey: APIManagerSerializer.locationsKey)
		aCoder.encode(events, forKey: APIManagerSerializer.eventsKey)
		aCoder.encode(map, forKey: APIManagerSerializer.mapKey)
		aCoder.encode(scanEvents, forKey: APIManagerSerializer.scanEventsKey)
	}
}
