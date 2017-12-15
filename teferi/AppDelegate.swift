import UIKit
import RxSwift
import Foundation
import UserNotifications

@UIApplicationMain
class AppDelegate : UIResponder, UIApplicationDelegate
{
    //MARK: Public Properties
    var window: UIWindow?

    //MARK: Private Properties
    fileprivate var dailyVotingNotificationDate : Date? = nil
    private let disposeBag = DisposeBag()
    private let notificationAuthorizedSubject = PublishSubject<Void>()
    
    private let timeService : TimeService
    private let metricsService : MetricsService
    private let loggingService : LoggingService
    private let feedbackService : FeedbackService
    private let locationService : LocationService
    private let settingsService : SettingsService
    private let timeSlotService : TimeSlotService
    private let editStateService : EditStateService
    private let smartGuessService : SmartGuessService
    private let trackEventService : TrackEventService
    private let appLifecycleService : AppLifecycleService
    private let notificationService : NotificationService
    private let motionService: MotionService
    private let selectedDateService : DefaultSelectedDateService
    private let goalService : GoalService
    
    private let coreDataStack : CoreDataStack
    
    //MARK: Initializers
    override init()
    {
        timeService = DefaultTimeService()
        metricsService = FirebaseMetricsService()
        settingsService = DefaultSettingsService(timeService: timeService)
        loggingService = SwiftyBeaverLoggingService()
        appLifecycleService = DefaultAppLifecycleService()
        editStateService = DefaultEditStateService(timeService: timeService)
        locationService = DefaultLocationService(loggingService: loggingService)
        motionService = DefaultMotionService(settingsService: settingsService)
        selectedDateService = DefaultSelectedDateService(timeService: timeService)
        feedbackService = MailFeedbackService(recipients: ["support@toggl.com"], subject: "Superday feedback", body: "")
        
        coreDataStack = CoreDataStack(loggingService: loggingService)
        let timeSlotPersistencyService = CoreDataPersistencyService(loggingService: loggingService, modelAdapter: TimeSlotModelAdapter(), managedObjectContext: coreDataStack.managedObjectContext)
        let locationPersistencyService = CoreDataPersistencyService(loggingService: loggingService, modelAdapter: LocationModelAdapter(), managedObjectContext: coreDataStack.managedObjectContext)
        let goalPersistencyService = CoreDataPersistencyService(loggingService: loggingService, modelAdapter: GoalModelAdapter(), managedObjectContext: coreDataStack.managedObjectContext)
                
        timeSlotService = DefaultTimeSlotService(timeService: timeService,
                                                 loggingService: loggingService,
                                                 locationService: locationService,
                                                 persistencyService: timeSlotPersistencyService)
        
        goalService = DefaultGoalService(timeService: timeService,
                                         timeSlotService: timeSlotService,
                                         loggingService: loggingService,
                                         metricsService: metricsService,
                                         settingsService: settingsService,
                                         persistencyService: goalPersistencyService)
                
        smartGuessService = DefaultSmartGuessService(timeService: timeService,
                                                     loggingService: loggingService,
                                                     settingsService: settingsService,
                                                     timeSlotService: timeSlotService)
        
        notificationService = DefaultNotificationService(timeService: timeService,
                                                            loggingService: loggingService,
                                                            settingsService: settingsService,
                                                            goalService: goalService)
        
        let trackEventServicePersistency = TrackEventPersistencyService(loggingService: loggingService,
                                                                        locationPersistencyService: locationPersistencyService)
        
        trackEventService = DefaultTrackEventService(loggingService: loggingService,
                                                     persistencyService: trackEventServicePersistency,
                                                     withEventSources: locationService)
    }
    
    //MARK: UIApplicationDelegate lifecycle
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        setVersionInSettings()
        setAppearance()
        
        goalService.logFinishedGoals()
        
        if settingsService.isFirstTimeAppRuns
        {
            settingsService.setShouldAskForNotificationPermission()
        }
        
        if !settingsService.didShowWelcomeMessage
        {
            settingsService.setIsFirstTimeAppRuns()
            settingsService.setIsPostCoreMotionUser()
        }
        
        let isInBackground = launchOptions?[UIApplicationLaunchOptionsKey.location] != nil
        
        logAppStartup(isInBackground)
        
        UNUserNotificationCenter.current().delegate = self
        
        //Faster startup when the app wakes up for location updates
        if isInBackground
        {
            appLifecycleService.publish(.movedToBackground)
            locationService.startLocationTracking()
            return true
        }
        
        initializeWindowIfNeeded()
        
        return true
    }

    private func setVersionInSettings()
    {
        let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as! String
        UserDefaults.standard.set("\(appVersionString) (\(buildNumber))", forKey: "version_string")
    }
    
    private func setAppearance()
    {
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().barTintColor = UIColor.white
    }
    
    private func logAppStartup(_ isInBackground: Bool)
    {
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        let startedOn = isInBackground ? "background" : "foreground"
        let message = "Application started on \(startedOn). App Version: \(versionNumber) Build: \(buildNumber)"

        loggingService.log(withLogLevel: .info, message: message)
    }
    
    private func initializeWindowIfNeeded()
    {
        guard window == nil else { return }
        
        metricsService.initialize()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let viewModelLocator = DefaultViewModelLocator(timeService: timeService,
                                                       metricsService: metricsService,
                                                       feedbackService: feedbackService,
                                                       locationService: locationService,
                                                       settingsService: settingsService,
                                                       timeSlotService: timeSlotService,
                                                       editStateService: editStateService,
                                                       smartGuessService : smartGuessService,
                                                       appLifecycleService: appLifecycleService,
                                                       selectedDateService: selectedDateService,
                                                       loggingService: loggingService,
                                                       notificationService: notificationService,
                                                       motionService: motionService,
                                                       trackEventService: trackEventService,
                                                       goalService: goalService)
        
        window!.rootViewController = IntroPresenter.create(with: viewModelLocator)
        window!.makeKeyAndVisible()
    }

    func applicationDidEnterBackground(_ application: UIApplication)
    {
        appLifecycleService.publish(.movedToBackground)
        locationService.startLocationTracking()
        
        notificationService.clearAndScheduleGoalNotifications()
    }

    func applicationDidBecomeActive(_ application: UIApplication)
    {
        notificationService.clearAndScheduleWeeklyNotifications()

        initializeWindowIfNeeded()
        
        appLifecycleService.publish(.movedToForeground(withDailyVotingNotificationDate: dailyVotingNotificationDate))
        dailyVotingNotificationDate = nil
    }
    
    func applicationWillTerminate(_ application: UIApplication)
    {
        coreDataStack.saveContext()
    }
    
    fileprivate func dailyVotingDate(_ notification: UNNotification) -> Date?
    {
        guard
            let type = notification.request.content.userInfo["notificationType"] as? String,
            type == NotificationType.repeatWeekly.rawValue,
            notification.date.dayOfWeek != 6
        else { return nil }
        
        return notification.date
    }
}

extension AppDelegate:UNUserNotificationCenterDelegate
{
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
    {
        if
            let typeString = response.notification.request.content.userInfo["notificationType"] as? String,
            let notificationType = NotificationType(rawValue: typeString),
            notificationType == .goal,
            let tabBarController = window?.rootViewController?.presentedViewController as? UITabBarController
        {
            tabBarController.selectedIndex = 1
        }
        
        dailyVotingNotificationDate = dailyVotingDate(response.notification)
        completionHandler()
    }
}
