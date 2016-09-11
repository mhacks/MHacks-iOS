//
//  Announcement.swift
//  MHacks
//
//  Created by Manav Gabhawala on 12/14/15.
//  Copyright © 2015 MHacks. All rights reserved.
//

import UIKit

struct Announcement: SerializableElementWithIdentifier {
	
	struct Category : OptionSet, CustomStringConvertible {
		let rawValue : Int
		static let None = Category(rawValue: 0 << 0)
		static let Emergency = Category(rawValue: 1 << 0)
		static let Logistics = Category(rawValue: 1 << 1)
		static let Food = Category(rawValue: 1 << 2)
		static let Swag = Category(rawValue: 1 << 3)
		static let Sponsor = Category(rawValue: 1 << 4)
		static let Other = Category(rawValue: 1 << 5)
		
		static let maxBit = 5
		var description: String {
			var categories = [String]()
			for i in 0...Category.maxBit
			{
				guard self.contains(Category(rawValue: 1 << i))
				else {
					continue
				}
				categories.append( {
					switch i
					{
					case 0:
						return "Emergency"
					case 1:
						return "Logistics"
					case 2:
						return "Food"
					case 3:
						return "Swag"
					case 4:
						return "Sponsor"
					case 5:
						return "Other"
					default:
						fatalError("Unrecognized category \(i)")
					}
				}())
			}
			guard categories.count > 0
			else {
				return "None"
			}
			return categories.joined(separator: ", ")
		}
		var color: UIColor {
			for i in 0...Category.maxBit
			{
				guard self.contains(Category(rawValue: 1 << i))
				else {
					continue
				}
				switch i
				{
				case 0:
					return UIColor(red: 255.0/255.0, green: 050.0/255.0, blue: 050.0/255.0, alpha: 1.0)
				case 1:
					return UIColor(red: 030.0/255.0, green: 103.0/255.0, blue: 254.0/255.0, alpha: 1.0)
				case 2:
					return UIColor(red: 255.0/255.0, green: 200.0/255.0, blue: 008.0/255.0, alpha: 1.0)
				case 3:
					return  UIColor(red: 057.0/255.0, green: 203.0/255.0, blue: 085.0/255.0, alpha: 1.0)
				case 4:
					return UIColor(red: 158.0/255.0, green: 030.0/255.0, blue: 229.0/255.0, alpha: 1.0)
				case 5:
					return UIColor(red: 247.0/255.0, green: 139.0/255.0, blue: 049.0/255.0, alpha: 1.0)
				default:
					fatalError("Unrecognized category \(i)")
				}
			}
			return UIColor.blue
		}
	}
	
	var ID: String
	var title: String
	var message: String
	var date: Date
	var category: Category
	var approved: Bool
		
	static private let todayDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.timeStyle = .short
		return formatter;
	}()
	
	static private let otherDayDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		formatter.doesRelativeDateFormatting = true;
		return formatter;
	}()
	
	var localizedDate: String {
		let formatter = Calendar.shared.isDateInToday(date) ? Announcement.todayDateFormatter : Announcement.otherDayDateFormatter
		return formatter.string(from: date)
	}
	
	
	static let dateFont: UIFont = {
		return UIFont.systemFont(ofSize: 14.0, weight: UIFontWeightThin)
	}()
}
extension Announcement
{
	private static let idKey = "id"
	private static let infoKey = "info"
	private static let titleKey = "name"
	private static let dateKey = "broadcast_time"
	private static let categoryKey = "category"
	private static let approvedKey = "is_approved"

	init?(_ serializedRepresentation: SerializedRepresentation) {
		guard let id = serializedRepresentation[Announcement.idKey] as? String, let title = serializedRepresentation[Announcement.titleKey] as? String, let message = serializedRepresentation[Announcement.infoKey] as? String, let date = serializedRepresentation[Announcement.dateKey] as? Double, let categoryRaw = serializedRepresentation[Announcement.categoryKey] as? Int, let approved = serializedRepresentation[Announcement.approvedKey] as? Bool
			else {
				return nil
		}
		self.init(ID: id, title: title, message: message, date: Date(timeIntervalSince1970: date), category: Category(rawValue: categoryRaw), approved: approved)
	}
	func toSerializedRepresentation() -> NSDictionary {
		return [Announcement.titleKey: title, Announcement.dateKey: date.timeIntervalSince1970, Announcement.infoKey: message, Announcement.categoryKey: category.rawValue]
	}
}


func <(lhs: Announcement, rhs: Announcement) -> Bool {
	return lhs.date < rhs.date
}

