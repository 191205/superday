import Foundation
import RxSwift

///ViewModel for the TimelineViewController.
class TimelineViewModel
{
    //MARK: Public Properties
    let date : Date
    var timelineItemsObservable : Observable<[TimelineItem]> { return self.timelineItems.asObservable() }

    //MARK: Private Properties
    private var isCurrentDay : Bool
    private let disposeBag = DisposeBag()
    
    private let timeService : TimeService
    private let timeSlotService : TimeSlotService
    private let editStateService : EditStateService
    private let appLifecycleService : AppLifecycleService
    private let loggingService : LoggingService
    private let settingsService : SettingsService
    private let metricsService : MetricsService
    
    private(set) var timelineItems : Variable<[TimelineItem]> = Variable([])
    
    var dailyVotingNotificationObservable : Observable<Date>
    {
        return self.appLifecycleService.startedOnDailyVotingNotificationDateObservable
    }
    
    var didBecomeActiveObservable : Observable<Void>
    {
        return self.appLifecycleService.movedToForegroundObservable
    }
    
    //MARK: Initializers
    init(date completeDate: Date,
         timeService: TimeService,
         timeSlotService: TimeSlotService,
         editStateService: EditStateService,
         appLifecycleService: AppLifecycleService,
         loggingService: LoggingService,
         settingsService: SettingsService,
         metricsService: MetricsService)
    {
        self.timeService = timeService
        self.timeSlotService = timeSlotService
        self.editStateService = editStateService
        self.appLifecycleService = appLifecycleService
        self.loggingService = loggingService
        self.settingsService = settingsService
        self.metricsService = metricsService
        self.date = completeDate.ignoreTimeComponents()
        
        isCurrentDay = timeService.now.ignoreTimeComponents() == date
        
        let timelineObservable = !isCurrentDay ? Observable.empty() : Observable<Int>.timer(1, period: 10, scheduler: MainScheduler.instance).mapTo(())
        
        let newTimeSlotForThisDate = !isCurrentDay ? Observable.empty() : timeSlotService
            .timeSlotCreatedObservable
            .filter(belogsToDate)
            .mapTo(())
        
        let updatedTimeSlotsForThisDate = timeSlotService.timeSlotsUpdatedObservable
            .map(timeSlotsBelogToDate)
            .mapTo(())
        
        let movedToForeground = appLifecycleService
            .movedToForegroundObservable
            .mapTo(())
        
        let refreshObservable =
            Observable.of(newTimeSlotForThisDate, updatedTimeSlotsForThisDate, movedToForeground, timelineObservable.mapTo(()))
                      .merge()
                      .startWith(()) // This is a hack I can't remove due to something funky with the view controllery lifecycle. We should fix this in the refactor
                
        refreshObservable
            .map(timeSlotsForToday)
            .map(toTimelineItems)
            .bindTo(timelineItems)
            .addDisposableTo(disposeBag)

    }
    
    //MARK: Public methods
    
    func notifyEditingBegan(point: CGPoint, item: TimelineItem? = nil)
    {
        let timelineItem: TimelineItem = item ?? timelineItems.value.last!
        
        editStateService
            .notifyEditingBegan(point: point,
                                timelineItem: timelineItem)
    }
    
    func calculateDuration(ofTimeSlot timeSlot: TimeSlot) -> TimeInterval
    {
        return timeSlotService.calculateDuration(ofTimeSlot: timeSlot)
    }
    
    func canShowVotingUI() -> Bool
    {
        return canShowVotingView(forDate: date)
    }
    
    func setVote(vote: Bool)
    {
        settingsService.setVote(forDate: date)
        metricsService.log(event: .timelineVote(date: timeService.now, voteDate: date, vote: vote))
    }
    
    
    //MARK: Private Methods
    private func belogsToDate(timeSlot: TimeSlot) -> Bool
    {
        return timeSlot.belongs(toDate: date)
    }
    
    private func timeSlotsBelogToDate(timeSlots: [TimeSlot]) -> [TimeSlot]
    {
        return timeSlots.belonging(toDate: date)
    }
    
    private func canShowVotingView(forDate date: Date) -> Bool
    {
        guard
            let installDate = settingsService.installDate,
            timeService.now.timeIntervalSince(date) < Constants.sevenDaysInSeconds &&
            ( timeService.now.ignoreTimeComponents() == date.ignoreTimeComponents() ? timeService.now.hour >= Constants.hourToShowDailyVotingUI : true ) &&
            installDate.ignoreTimeComponents() != date.ignoreTimeComponents()
        else { return false }
        
        let alreadyVoted = !settingsService.lastSevenDaysOfVotingHistory().contains(date.ignoreTimeComponents())
        
        return alreadyVoted
    }
    
    private func timeSlotsForToday() -> [TimeSlot]
    {
        return timeSlotService.getTimeSlots(forDay: date)
    }
    
    private func toTimelineItems(fromTimeSlots timeSlots: [TimeSlot]) -> [TimelineItem]
    {
        return timeSlots.toTimelineItems(timeSlotService: timeSlotService, isCurrentDay: isCurrentDay)
    }
    
    private func expandedTimelineItems(fromTimeSlots timeSlots: [TimeSlot]) -> [TimelineItem]
    {
        guard let first = timeSlots.first, let last = timeSlots.last, first.startTime != last.startTime else { return [] }
        let category = first.category
        
        return timeSlots.map {
            TimelineItem(
                withTimeSlots: [$0],
                category: category,
                duration: calculateDuration(ofTimeSlot: $0),
                shouldDisplayCategoryName: $0.startTime == first.startTime)
        }
    }
    
    private func timelineItem(fromTimeSlot timeSlot: TimeSlot) -> TimelineItem
    {
        return TimelineItem(
            withTimeSlots: [timeSlot],
            category: timeSlot.category,
            duration: calculateDuration(ofTimeSlot: timeSlot))
    }
    
    private func isLastInPastDay(_ index: Int, count: Int) -> Bool
    {
        guard !isCurrentDay else { return false }
        
        let isLastEntry = count - 1 == index
        return isLastEntry
    }
}
