//
//  Configuration.swift
//  MHacks
//
//  Created by Connor Krupp on 8/28/17.
//  Copyright © 2017 MHacks. All rights reserved.
//

import UIKit

final class Configuration : Serializable {
    
    // MARK : - Properties
    private(set) var startDate: Date
    private(set) var endDate: Date

    let semaphoreGuard = DispatchSemaphore(value: 1)
    let coalescer = CoalescedCallbacks()
    private(set) var lastUpdated: Int?
    
    private static let startDateKey = "start_date"
    private static let endDateKey = "end_date"

    init(startDate: Date = Date(timeIntervalSince1970: 150603840), endDate: Date = Date(timeIntervalSince1970: 150621120)) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    convenience init?(_ serializedRepresentation: SerializedRepresentation) {
        self.init()
        _ = updateWith(serializedRepresentation)
    }
    
    func toSerializedRepresentation() -> NSDictionary {
        return [Configuration.startDateKey: startDate.timeIntervalSince1970, Configuration.endDateKey: endDate.timeIntervalSince1970]
    }
    
    func updateWith(_ serialized: SerializedRepresentation) -> Bool {
        guard let config = serialized["configuration"] as? [String: Any] else {
            return false
        }
        
        guard let startDate = config[Configuration.startDateKey] as? Double,
              let endDate = config[Configuration.endDateKey] as? Double
        else {
            return false
        }
        
        self.startDate = Date(timeIntervalSince1970: startDate / 1000)
        self.endDate = Date(timeIntervalSince1970: endDate / 1000)
        
        return true
    }
    
    // MARK: Countdown Formatting
    
    func progress() -> Double {
        let duration = self.endDate.timeIntervalSince1970 - self.startDate.timeIntervalSince1970
        return 1.0 - self.timeRemaining() / duration
    }
    
    private func progressDate(for date: Date = Date()) -> Date {
        return min(max(date, self.startDate), endDate)
    }
    
    private func timeRemaining(for date: Date = Date()) -> TimeInterval {
        return self.endDate.timeIntervalSince(progressDate(for: date))
    }
    
    private var roundedTimeRemaining: TimeInterval {
        return round(self.timeRemaining())
    }
    
    private var timeRemainingDescription: String {
        
        let total = Int(self.roundedTimeRemaining)
        
        let hours = Configuration.timeRemainingFormatter.string(for: total / 3600)!
        let minutes = Configuration.timeRemainingFormatter.string(for: (total % 3600) / 60)!
        let seconds = Configuration.timeRemainingFormatter.string(for: total % 60)!
        
        return "\(hours):\(minutes):\(seconds)"
    }
    
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.formattingContext = .middleOfSentence
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        
        return formatter
    }()
    
    private static var timeRemainingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        
        formatter.minimumIntegerDigits = 2
        
        return formatter
    }()
}
