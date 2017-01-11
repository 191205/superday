import CoreLocation
import CoreMotion
import UIKit
import Foundation

/// Default implementation of the TrackingService.
class DefaultTrackingService : TrackingService
{
    // MARK: Fields
    private let notificationBody = "NotificationBody".translate()
    private let notificationTitle = "NotificationTitle".translate()
    private let commuteDetectionLimit = TimeInterval(25 * 60)
    
    private let timeService : TimeService
    private let loggingService : LoggingService
    private let settingsService : SettingsService
    private let timeSlotService : TimeSlotService
    private let smartGuessService : SmartGuessService
    private let notificationService : NotificationService
    
    private var isOnBackground = false
    
    //MARK: Init
    init(timeService: TimeService,
         loggingService: LoggingService,
         settingsService: SettingsService,
         timeSlotService: TimeSlotService,
         smartGuessService: SmartGuessService,
         notificationService: NotificationService)
    {
        self.timeService = timeService
        self.loggingService = loggingService
        self.settingsService = settingsService
        self.timeSlotService = timeSlotService
        self.smartGuessService = smartGuessService
        self.notificationService = notificationService
        
        notificationService.subscribeToCategoryAction(self.onNotificationAction)
    }
    
    //MARK:  TrackingService implementation
    func onLocation(_ location: CLLocation)
    {
        guard self.isOnBackground else { return }
        
        guard let previousLocation = self.settingsService.lastLocation else
        {
            self.settingsService.setLastLocation(location)
            return
        }
        
        guard location.timestamp > previousLocation.timestamp else { return }
        
        guard self.locationsAreSignificantlyDifferent(current: location, previous: previousLocation) else
        {
            if location.isMoreAccurate(than: previousLocation)
            {
                self.settingsService.setLastLocation(location)
            }
            return
        }
        
        self.settingsService.setLastLocation(location)
        
        guard let currentTimeSlot = self.timeSlotService.getLast() else { return }
        
        let scheduleNotification : Bool
        
        if self.isCommute(now: location.timestamp, then: previousLocation.timestamp)
        {
            if currentTimeSlot.startTime == previousLocation.timestamp
            {
                if !currentTimeSlot.categoryWasSetByUser
                {
                    self.timeSlotService.update(timeSlot: currentTimeSlot, withCategory: .commute, setByUser: false)
                }
            }
            else if currentTimeSlot.category != .commute
            {
                self.startCommute(fromLocation: previousLocation)
            }
            scheduleNotification = true
        }
        else
        {
            if currentTimeSlot.startTime < previousLocation.timestamp
            {
                self.persistTimeSlot(withLocation: previousLocation)
            }
            
            //We should keep the coordinates at the startDate.
            let guessedCategory = self.persistTimeSlot(withLocation: location)
            
            //We only schedule notifications if we couldn't guess any category
            scheduleNotification = guessedCategory == .unknown
        }
        
        self.cancelNotification(andScheduleNew: scheduleNotification)
    }
    
    private func locationsAreSignificantlyDifferent(current: CLLocation, previous: CLLocation) -> Bool
    {
        let higherInaccuracy = max(current.horizontalAccuracy, previous.horizontalAccuracy)
        let thresholdDistance = higherInaccuracy * 2
        
        return current.distance(from: previous) > thresholdDistance
    }
    
    private func cancelNotification(andScheduleNew scheduleNew : Bool)
    {
        self.notificationService.unscheduleAllNotifications()
        
        guard scheduleNew else { return }
        
        let notificationDate = self.timeService.now.addingTimeInterval(self.commuteDetectionLimit)
        self.notificationService.scheduleNotification(date: notificationDate,
                                                      title: self.notificationTitle,
                                                      message: self.notificationBody)
    }
    
    private func onNotificationAction(withCategory category : Category)
    {
        self.tryStoppingCommuteRetroactively(at: self.timeService.now)
        
        guard let currentTimeSlot = self.timeSlotService.getLast() else { return }
        self.timeSlotService.update(timeSlot: currentTimeSlot, withCategory: category, setByUser: true)
    }
    
    private func onAppActivates(at time : Date)
    {
        self.tryStoppingCommuteRetroactively(at: time)
    }
    
    private func tryStoppingCommuteRetroactively(at time : Date)
    {
        guard let lastLocation = self.settingsService.lastLocation else { return }
        
        guard
            let currentTimeSlot = self.timeSlotService.getLast(),
            currentTimeSlot.category == .commute,
            currentTimeSlot.startTime < lastLocation.timestamp,
            !self.isCommute(now: time, then: lastLocation.timestamp)
        else { return }
        
        self.persistTimeSlot(withLocation: lastLocation)
    }
    
    private func isCommute(now : Date, then : Date) -> Bool
    {
        return now.timeIntervalSince(then) < self.commuteDetectionLimit
    }
    
    func onAppState(_ appState: AppState)
    {
        if appState == .active
        {
            self.onAppActivates(at: self.timeService.now)
        }
        
        self.isOnBackground = appState == .inactive
    }
    
    private func startCommute(fromLocation location: CLLocation)
    {
        let timeSlot = TimeSlot(withStartTime: location.timestamp, category: .commute, location: location, categoryWasSetByUser: false);
        
        self.timeSlotService.add(timeSlot: timeSlot)
    }
    
    @discardableResult private func persistTimeSlot(withLocation location: CLLocation) -> Category
    {
        let smartGuess = self.smartGuessService.get(forLocation: location)
        
        let timeSlot = smartGuess == nil ?
            TimeSlot(withStartTime: location.timestamp, category: .unknown, location: location, categoryWasSetByUser: false) :
            TimeSlot(withStartTime: location.timestamp, smartGuess: smartGuess!, location: location)
        
        self.timeSlotService.add(timeSlot: timeSlot)
        
        return smartGuess?.category ?? .unknown
    }
}
