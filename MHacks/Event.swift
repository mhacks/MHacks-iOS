//
//  Event.swift
//  MHacks
//
//  Created by Russell Ladd on 9/30/14.
//  Copyright (c) 2014 MHacks. All rights reserved.
//

import Foundation
import UIKit


final class Event: SerializableElementWithIdentifier {
 
	enum Category: String, CustomStringConvertible {
		case general = "General"
		case logisitics = "Logistics"
		case food = "Food"
		case learn = "Learn"
		case social = "Social"
		
		var color: UIColor {
			switch self {
			case .general:
				return MHacksColor.blue
			case .logisitics:
				return MHacksColor.orange
			case .food:
				return MHacksColor.yellow
			case .learn:
				return MHacksColor.purple
			case .social:
				return MHacksColor.red
			}
		}
		
		var description : String {
			return self.rawValue
		}
	}
	
	let ID: String
	static var resultsKey: String {
		return "events"
	}
    let name: String
	let category: Category
	fileprivate let locationID: String
    let startDate: Date
	let endDate: Date
    let desc: String
	
	var duration: Double {
		return 60
	}
	
	init(ID: String, name: String, category: Category, locationID: String, startDate: Date, endDate: Date, desc: String) {
		self.ID = ID
		self.name = name
		self.category = category
		self.locationID = locationID
		self.startDate = startDate
		self.endDate = endDate
		self.desc = desc
	}

	
    var timeInterval: Range<TimeInterval> {
        return startDate.timeIntervalSinceReferenceDate..<endDate.timeIntervalSinceReferenceDate
    }
	
	var location: Location? {
		return APIManager.shared.locations[locationID]
	}
}

extension Event {
	private static let nameKey = "name"
	private static let descKey = "desc"
	private static let locationIDKey = "location"
	private static let startDateKey = "startDate"
	private static let endDateKey = "endDate"
	private static let categoryKey = "category"
	
	convenience init?(_ serialized: SerializedRepresentation) {
		guard
			let name = serialized[Event.nameKey] as? String,
			let categoryRaw = serialized[Event.categoryKey] as? String,
			let locationID = serialized[Event.locationIDKey] as? String,
			let category = Category(rawValue: categoryRaw),
			let startDate = serialized[Event.startDateKey] as? Double,
			let endDate = serialized[Event.endDateKey] as? Double,
			let desc = serialized[Event.descKey] as? String,
			let ID = serialized[Event.idKey] as? String
		else {
			return nil
		}
		
		self.init(
			ID: ID,
			name: name,
			category: category,
			locationID: locationID,
			startDate: Date(timeIntervalSince1970: startDate / 1000),
			endDate: Date(timeIntervalSince1970: endDate / 1000),
			desc: desc
		)
	}
	
	func toSerializedRepresentation() -> NSDictionary {
		return [
			Event.idKey: ID,
			Event.nameKey: name,
			Event.locationIDKey: locationID,
			Event.startDateKey: startDate.timeIntervalSince1970,
			Event.endDateKey: endDate,
			Event.descKey: desc,
			Event.categoryKey: category.rawValue
		]
	}
}
func < (lhs: Event, rhs: Event) -> Bool {
	return lhs.startDate < rhs.startDate
}

