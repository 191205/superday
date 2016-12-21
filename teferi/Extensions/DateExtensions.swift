import Foundation

extension Date
{
    //MARK: Properties

    ///Returns the day before the current date
    var yesterday : Date
    {
        return self.add(days: -1)
    }

    ///Returns the day after the current date
    var tomorrow : Date
    {
        return self.add(days: 1)
    }
    
    //MARK: Methods
    
    /**
     Add (or subtract, if the value is negative) days to this date.
     
     - Parameter daysToAdd: Days to be added to the date.
     
     - Returns: A new date that is `daysToAdd` ahead of this one.
     */
    func add(days daysToAdd: Int) -> Date
    {
        var dayComponent = DateComponents()
        dayComponent.day = daysToAdd
        
        let calendar = Calendar.current
        let nextDate = (calendar as NSCalendar).date(byAdding: dayComponent, to: self, options: NSCalendar.Options())!
        return nextDate
    }
    
    /**
     Ignores the time portion of the Date.
     
     - Returns: A new date whose time is always midnight.
     */
    func ignoreTimeComponents() -> Date
    {
        let units : NSCalendar.Unit = [ .year, .month, .day];
        let calendar = Calendar.current;
        return calendar.date(from: (calendar as NSCalendar).components(units, from: self))!
    }
    
    //period -> .WeekOfYear, .Day
    func rangeOfPeriod(period: Calendar.Component) -> (Date, Date)
    {
        var startDate = Date()
        var interval: TimeInterval = 0
        let _ = Calendar.current.dateInterval(of: period,
                                              start: &startDate, interval: &interval, for: self)
        let endDate = startDate.addingTimeInterval(interval - 1)
        return (startDate, endDate)
    }

    func calcStartAndEndOfDay() -> (Date, Date)
    {
        return self.rangeOfPeriod(period: .day)
    }

    func calcStartAndEndOfWeek() -> (Date, Date)
    {
        return self.rangeOfPeriod(period: .weekday)
    }

    func calcStartAndEndOfMonth() -> (Date, Date)
    {
        return self.rangeOfPeriod(period: .month)
    }

    func getStart() -> Date
    {
        let (start, _) = self.calcStartAndEndOfDay()
        return start
    }

    
    var daysInMonth : Int
    {
        let dateComponents = DateComponents(year: self.year, month: self.month)
        let calendar = Calendar.current
        let date = calendar.date(from: dateComponents)!
        
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.count
    }
    
    var dayOfWeek : Int { return Calendar.current.component(.weekday, from: self) - 1 }
    
    var day : Int { return Calendar.current.component(.day, from: self) }
    
    var month : Int { return Calendar.current.component(.month, from: self) }
    
    var year: Int { return Calendar.current.component(.year, from: self) }
    
    func differenceInDays(toDate date: Date) -> Int
    {
        let calendar = Calendar.current
        let units = Set<Calendar.Component>([ .day]);
        
        let components = calendar.dateComponents(units, from: self.ignoreTimeComponents(), to: date.ignoreTimeComponents())

        return components.day!
    }
}
