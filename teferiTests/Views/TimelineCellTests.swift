import Foundation
import XCTest
import Nimble
@testable import teferi

class TimelineCellTests : XCTestCase
{
    // MARK: Fields
    private let timeSlot = TimeSlot(category: .Work)
    private var view = TimelineCell()
    
    private var imageIcon : UIImageView
    {
        let view = self.view.subviews.filter { v in v is UIImageView  }.first!
        return view as! UIImageView
    }
    
    private var slotDescription : UILabel
    {
        let view = self.view.subviews.filter { v in v is UILabel  }.first!
        return view as! UILabel
    }
    
    private var timeLabel : UILabel
    {
        let view = self.view.subviews.filter { v in v is UILabel  }.last!
        return view as! UILabel
    }
    
    private var line : UIView
    {
        return  self.view.subviews.first!
    }
    
    override func setUp()
    {
        view = NSBundle.mainBundle().loadNibNamed("TimelineCell", owner: nil, options: nil).first! as! TimelineCell
        view.bindTimeSlot(timeSlot)
    }
    
    func testTheImageChangesAccordingToTheBoundTimeSlot()
    {
        expect(self.imageIcon.image).notTo(beNil())
    }
    
    func testTheDescriptionChangesAccordingToTheBoundTimeSlot()
    {
        let formatter = NSDateFormatter()
        formatter.timeStyle = .MediumStyle
        let dateString = formatter.stringFromDate(timeSlot.startTime)
        
        let expectedText = "\(timeSlot.category) \(dateString)"
        expect(self.slotDescription.text).to(equal(expectedText))
    }
    
    func testTheDescriptionHasNoCategoryWhenTheCategoryIsUnknown()
    {
        let unknownTimeSlot = TimeSlot()
        view.bindTimeSlot(unknownTimeSlot)
        let formatter = NSDateFormatter()
        formatter.timeStyle = .MediumStyle
        let dateString = formatter.stringFromDate(unknownTimeSlot.startTime)
        
        let expectedText = " \(dateString)"
        expect(self.slotDescription.text).to(equal(expectedText))
    }
    
    func testTheElapsedTimeLabelShowsOnlyMinutesWhenLessThanAnHourHasPassed()
    {
        let minuteMask = "%02d min"
        let interval = Int(timeSlot.duration)
        let minutes = (interval / 60) % 60
        
        let expectedText = String(format: minuteMask, minutes)
        expect(self.timeLabel.text).to(equal(expectedText))
    }
    
    func testTheElapsedTimeLabelShowsHoursAndMinutesWhenOverAnHourHasPassed()
    {
        let newTimeSlot = TimeSlot()
        newTimeSlot.startTime = NSDate().addDays(-1)
        view.bindTimeSlot(newTimeSlot)
        
        let hourMask = "%02d h %02d min"
        let interval = Int(newTimeSlot.duration)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        
        let expectedText = String(format: hourMask, hours, minutes)
        expect(self.timeLabel.text).to(equal(expectedText))
    }
    
    func testTheElapsedTimeLabelColorChangesAccordingToTheBoundTimeSlot()
    {
        let expectedColor = Category.Work.color
        let actualColor = timeLabel.textColor!
        
        let expectedComponents = CGColorGetComponents(expectedColor.CGColor)
        let expectedRed = expectedComponents[0]
        let expectedGreen = expectedComponents[1]
        let expectedBlue = expectedComponents[2]
        
        let actualComponents = CGColorGetComponents(actualColor.CGColor)
        let actualRed = actualComponents[0]
        let actualGreen = actualComponents[1]
        let actualBlue = actualComponents[2]
        
        expect(expectedRed).to(equal(actualRed))
        expect(expectedGreen).to(equal(actualGreen))
        expect(expectedBlue).to(equal(actualBlue))
    }
    
    func testTheTimelineCellLineHeightChangesAccordingToTheBoundTimeSlot()
    {
        let oldLineHeight = line.frame.height
        let newTimeSlot = TimeSlot()
        newTimeSlot.startTime = NSDate().addDays(-1)
        newTimeSlot.endTime = NSDate()
        view.bindTimeSlot(newTimeSlot)
        view.layoutIfNeeded()
        let newLineHeight = line.frame.height
        
        expect(oldLineHeight).to(beLessThan(newLineHeight))
    }
    
    func testTheLineColorChangesAccordingToTheBoundTimeSlot()
    {
        let expectedColor = Category.Work.color
        let actualColor = line.backgroundColor!
        
        let expectedComponents = CGColorGetComponents(expectedColor.CGColor)
        let expectedRed = expectedComponents[0]
        let expectedGreen = expectedComponents[1]
        let expectedBlue = expectedComponents[2]
        
        let actualComponents = CGColorGetComponents(actualColor.CGColor)
        let actualRed = actualComponents[0]
        let actualGreen = actualComponents[1]
        let actualBlue = actualComponents[2]
        
        expect(expectedRed).to(equal(actualRed))
        expect(expectedGreen).to(equal(actualGreen))
        expect(expectedBlue).to(equal(actualBlue))
    }
}