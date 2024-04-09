//
//  CalendarViewModel.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import Foundation
import iCalendarParser
import os
import SwiftUI

// Disable swiftlint warnings because of hardcoded iCal value (file becomes too long)
// swiftlint:disable superfluous_disable_command type_body_length function_body_length file_length
/// ViewModel fetching data from Confluence, parsing the calendar and preparing the data for ``CalendarView``.
@Observable class CalendarViewModel {
    private let logger = Logger()
    private weak var model: Model?
    private var rawEvents: [ICEvent] = []
    private var events: [Event] = []
    var timer = Timer()
    var errorOnNetworkCallOccured = false

    init(model: Model) {
        self.model = model
        updateEvents()
        
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] _ in
            self?.updateEvents()
        })
    }
    
    /// Updating the events. This includes fetching the calendar and parsing it.
    private func updateEvents() {
        logger.trace("Updating events")
        guard let username = model?.username, let password = model?.password else {
            logger.warning("Username or password unset")
            return
        }
        
        let iCalLink = "https://\(username):\(password)@confluence.ase.in.tum.de/rest/calendar-services/1.0/calendar/export/subcalendar/7eac5fd4-7907-4590-89fe-bd9ab405efde.ics?os_authType=basic&isSubscribe=true"
        
        guard let url = URL(string: iCalLink) else {
            logger.error("Failed to create URL: \(iCalLink)")
            errorOnNetworkCallOccured = true
            return
        }
        
        Task {
            let iCalString: String
            do {
                iCalString = try await fetchString(from: url)
            } catch {
                errorOnNetworkCallOccured = true
                return
            }
            
            guard let calendar = ICParser().calendar(from: iCalString) else {
                logger.error("Failed to parse result as iCal object")
                errorOnNetworkCallOccured = true
                return
            }
            
            rawEvents = calendar.events.filter {event in
                guard let summary = event.summary else {
                    return false
                }
                return summary.lowercased().contains("hausmeister")
            }
            self.rawEvents = rawEvents
            
            do {
                try parseEvents()
            } catch {
                errorOnNetworkCallOccured = true
                return
            }
            errorOnNetworkCallOccured = false
        }
    }
    
    /// Parsing the iCal events, extracting relevant information (start date, end date, and attendee), and rearranges the events to end in the future.
    func parseEvents() throws {
        logger.trace("Parsing iCal events")
        
        events = try self.rawEvents.map {event in
            guard let startDate = event.dtStart,
                  let endDate = event.dtEnd,
                  let frequency = event.recurrenceRule?.interval,
                  var attendee = event.attendees?.first?.cname else {
                logger.error("Failed to read keys from iCal object: \(event.uid)")
                throw CalendarParsingError.wrongFormat
            }
            
            // Some names in iCal are wrapped in quotation marks
            attendee = attendee.replacingOccurrences(of: "\"", with: "")
            
            // Add/Subtract at least 3 hours to prevent issues with time change (summer/winter time)
            var normalisedStartDate = startDate.date.addHours(3).noon
            var normalisedEndDate = endDate.date.addHours(-3).noon
            
//            In iCal for reoccuring events, the start and end date of the first event is stored.
//            There is a property that saves, how often and in which interval the event is repeated.
//            Thus, the fetched data looks something like this
//
//            +---------+ +---------+ +---------+ +---------+
//            | Admin 1 | | Admin 2 | | Admin 3 | | Admin 4 |
//            +---------+ +---------+ +---------+ +---------+
//            ^         ^                                         ...    ^
//            |         |                                                |
//            First start date                                          now
//                      |- First end date
//            With this method, we want to extrapolate this data, so we get the dates of the current round of events.
//            +---------+ +---------+ +---------+ +---------+
//            | Admin 3 | | Admin 4 | | Admin 1 | | Admin 2 |
//            +---------+ +---------+ +---------+ +---------+
//                 ^
//                 |
//                now
            
            let secondsPerRound = Double((frequency * 7 * 24 * 60 * 60))
            let absoluteTimeInterval = abs(normalisedEndDate.timeIntervalSinceNow)
            
            let numberOfRoundsToAdd = Int((absoluteTimeInterval / secondsPerRound).rounded(.up))
            
            normalisedStartDate = normalisedStartDate.addWeeks(numberOfRoundsToAdd * frequency)
            normalisedEndDate = normalisedEndDate.addWeeks(numberOfRoundsToAdd * frequency)

            return Event(attendee: attendee, startDate: normalisedStartDate, endDate: normalisedEndDate)
        }
    }
    
    /// Fetching the string from the given URL. Throws an ``CalendarParsingError/invalidCredentials`` error if the server returns an error code.
    /// - Parameter url: The URL from which the data should be fetched.
    /// - Returns: The string returned from the webserver.
    private func fetchString(from url: URL) async throws -> String {
        logger.trace("Fetching data from server")
        
        // For testing:
//        return """
//BEGIN:VCALENDAR
//PRODID:-//Atlassian Confluence//Calendar Plugin 1.0//EN
//VERSION:2.0
//CALSCALE:GREGORIAN
//X-WR-CALNAME:Hausmeister
//X-WR-CALDESC:
//X-WR-TIMEZONE:Europe/Berlin
//X-MIGRATED-FOR-USER-KEY:true
//METHOD:PUBLISH
//X-CONFLUENCE-CUSTOM-EVENT-TYPE;X-CONFLUENCE-CUSTOM-TYPE-ID=507ab3c3-550a-
// 401c-8ae8-6da5bd06f384;X-CONFLUENCE-CUSTOM-TYPE-TITLE=Hausmeister;X-CONF
// LUENCE-CUSTOM-TYPE-ICON=home;X-CONFLUENCE-CUSTOM-TYPE-REMINDER-DURATION=
// 0:true
//BEGIN:VTIMEZONE
//TZID:Europe/Berlin
//LAST-MODIFIED:20201010T011803Z
//TZURL:http://tzurl.org/zoneinfo/Europe/Berlin
//X-LIC-LOCATION:Europe/Berlin
//X-PROLEPTIC-TZNAME:LMT
//UID:20240404T170930Z--936406136@confluence.ase.in.tum.de
//SEQUENCE:1
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+005328
//TZOFFSETTO:+0100
//DTSTART:18930401T000000
//END:STANDARD
//BEGIN:DAYLIGHT
//TZNAME:CEST
//TZOFFSETFROM:+0100
//TZOFFSETTO:+0200
//DTSTART:19160430T230000
//RDATE:19400401T020000
//RDATE:19430329T020000
//RDATE:19460414T020000
//RDATE:19470406T030000
//RDATE:19480418T020000
//RDATE:19490410T020000
//RDATE:19800406T020000
//END:DAYLIGHT
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+0200
//TZOFFSETTO:+0100
//DTSTART:19161001T010000
//RDATE:19421102T030000
//RDATE:19431004T030000
//RDATE:19441002T030000
//RDATE:19451118T030000
//RDATE:19461007T030000
//END:STANDARD
//BEGIN:DAYLIGHT
//TZNAME:CEST
//TZOFFSETFROM:+0100
//TZOFFSETTO:+0200
//DTSTART:19170416T020000
//RRULE:FREQ=YEARLY;UNTIL=19180415T010000Z;BYMONTH=4;BYDAY=3MO
//END:DAYLIGHT
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+0200
//TZOFFSETTO:+0100
//DTSTART:19170917T030000
//RRULE:FREQ=YEARLY;UNTIL=19180916T010000Z;BYMONTH=9;BYDAY=3MO
//END:STANDARD
//BEGIN:DAYLIGHT
//TZNAME:CEST
//TZOFFSETFROM:+0100
//TZOFFSETTO:+0200
//DTSTART:19440403T020000
//RRULE:FREQ=YEARLY;UNTIL=19450402T010000Z;BYMONTH=4;BYDAY=1MO
//END:DAYLIGHT
//BEGIN:DAYLIGHT
//TZNAME:CEMT
//TZOFFSETFROM:+0200
//TZOFFSETTO:+0300
//DTSTART:19450524T020000
//RDATE:19470511T030000
//END:DAYLIGHT
//BEGIN:DAYLIGHT
//TZNAME:CEST
//TZOFFSETFROM:+0300
//TZOFFSETTO:+0200
//DTSTART:19450924T030000
//RDATE:19470629T030000
//END:DAYLIGHT
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+0100
//TZOFFSETTO:+0100
//DTSTART:19460101T000000
//RDATE:19800101T000000
//END:STANDARD
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+0200
//TZOFFSETTO:+0100
//DTSTART:19471005T030000
//RRULE:FREQ=YEARLY;UNTIL=19491002T010000Z;BYMONTH=10;BYDAY=1SU
//END:STANDARD
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+0200
//TZOFFSETTO:+0100
//DTSTART:19800928T030000
//RRULE:FREQ=YEARLY;UNTIL=19950924T010000Z;BYMONTH=9;BYDAY=-1SU
//END:STANDARD
//BEGIN:DAYLIGHT
//TZNAME:CEST
//TZOFFSETFROM:+0100
//TZOFFSETTO:+0200
//DTSTART:19810329T020000
//RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
//END:DAYLIGHT
//BEGIN:STANDARD
//TZNAME:CET
//TZOFFSETFROM:+0200
//TZOFFSETTO:+0100
//DTSTART:19961027T030000
//RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
//END:STANDARD
//END:VTIMEZONE
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240115
//DTEND;VALUE=DATE:20240122
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1896
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133145Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//CREATED:20240115T133145Z
//LAST-MODIFIED:20240115T134152Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fd9117c6102d2017c97bc639200b7;CN="Ignac
// io Alejandro García Nunez";CUTYPE=INDIVIDUAL:mailto:garcia.nunez@tum.de
//SEQUENCE:2
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240122
//DTEND;VALUE=DATE:20240129
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1897
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133217Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//CREATED:20240115T133217Z
//LAST-MODIFIED:20240115T134213Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa679749b03fe01754c79d52901a6;CN=Benjam
// in Sebastian Schmitz;CUTYPE=INDIVIDUAL:mailto:benjamin.schmitz@tum.de
//SEQUENCE:2
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240129
//DTEND;VALUE=DATE:20240205
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1898
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133403Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//CREATED:20240115T133403Z
//LAST-MODIFIED:20240115T134227Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa6756602007f0166020b6fd81639;CN=Robert
//  Jandow;CUTYPE=INDIVIDUAL:mailto:robert.jandow@tum.de
//SEQUENCE:2
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240205
//DTEND;VALUE=DATE:20240212
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1899
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133435Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//CREATED:20240115T133436Z
//LAST-MODIFIED:20240115T134234Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa679749b03fe017528db2e8b013e;CN=Colin
// Wilk;CUTYPE=INDIVIDUAL:mailto:colin.wilk@tum.de
//SEQUENCE:2
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240212
//DTEND;VALUE=DATE:20240219
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1900
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133521Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//CREATED:20240115T133521Z
//LAST-MODIFIED:20240115T134240Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magnu
// s Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//SEQUENCE:2
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240219
//DTEND;VALUE=DATE:20240226
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1901
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133547Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//CREATED:20240115T133547Z
//LAST-MODIFIED:20240115T134245Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa6756a2c9355016a4ffbb1d40294;CN=Timor
// Morrien;CUTYPE=INDIVIDUAL:mailto:timor.morrien@tum.de
//SEQUENCE:3
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240115
//DTEND;VALUE=DATE:20240122
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1902
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133145Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//RECURRENCE-ID;VALUE=DATE:20240115
//CREATED:20240115T133835Z
//LAST-MODIFIED:20240115T133947Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fd9117c6102d2017c97bc639200b7;CN="Ignac
// io Alejandro García Nunez";CUTYPE=INDIVIDUAL:mailto:garcia.nunez@tum.de
//SEQUENCE:2
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240122
//DTEND;VALUE=DATE:20240129
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1903
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133217Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//RECURRENCE-ID;VALUE=DATE:20240122
//CREATED:20240115T134033Z
//LAST-MODIFIED:20240115T134033Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa679749b03fe01754c79d52901a6;CN=Benjam
// in Sebastian Schmitz;CUTYPE=INDIVIDUAL:mailto:benjamin.schmitz@tum.de
//SEQUENCE:1
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240129
//DTEND;VALUE=DATE:20240205
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1904
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133403Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//RECURRENCE-ID;VALUE=DATE:20240129
//CREATED:20240115T134055Z
//LAST-MODIFIED:20240115T134055Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa6756602007f0166020b6fd81639;CN=Robert
//  Jandow;CUTYPE=INDIVIDUAL:mailto:robert.jandow@tum.de
//SEQUENCE:1
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240205
//DTEND;VALUE=DATE:20240212
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1905
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133435Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//RECURRENCE-ID;VALUE=DATE:20240205
//CREATED:20240115T134106Z
//LAST-MODIFIED:20240115T134106Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa679749b03fe017528db2e8b013e;CN=Colin
// Wilk;CUTYPE=INDIVIDUAL:mailto:colin.wilk@tum.de
//SEQUENCE:1
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//BEGIN:VEVENT
//DTSTAMP:20240404T170930Z
//DTSTART;VALUE=DATE:20240212
//DTEND;VALUE=DATE:20240219
//SUMMARY:ITG Hausmeister
//X-CONFLUENCE-CUSTOM-TYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//CATEGORIES:Hausmeister
//SUBCALENDAR-ID:212853cb-8d3e-494a-88b3-0577375ac621
//PARENT-CALENDAR-ID:7eac5fd4-7907-4590-89fe-bd9ab405efde
//PARENT-CALENDAR-NAME:
//SUBSCRIPTION-ID:
//SUBCALENDAR-TZ-ID:Europe/Berlin
//SUBCALENDAR-NAME:Hausmeister
//EVENT-ID:1906
//EVENT-ALLDAY:true
//CUSTOM-EVENTTYPE-ID:507ab3c3-550a-401c-8ae8-6da5bd06f384
//UID:20240115T133521Z-1627065431@confluence.ase.in.tum.de
//DESCRIPTION:
//ORGANIZER;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magn
// us Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//RRULE:FREQ=WEEKLY;INTERVAL=6;BYDAY=MO
//RECURRENCE-ID;VALUE=DATE:20240212
//CREATED:20240115T134118Z
//LAST-MODIFIED:20240115T134118Z
//ATTENDEE;X-CONFLUENCE-USER-KEY=031fa679749b03fe01757f54a20e0297;CN="Magnu
// s Kühne";CUTYPE=INDIVIDUAL:mailto:magnus.kuehne@tum.de
//SEQUENCE:1
//X-CONFLUENCE-SUBCALENDAR-TYPE:custom
//STATUS:CONFIRMED
//END:VEVENT
//END:VCALENDAR
//""".replacingOccurrences(of: "\n", with: "\r\n")

        let tuple: (Data, URLResponse)? = try? await URLSession.shared.data(from: url)
        let data = tuple?.0

        guard let data, let string = String(data: data, encoding: .utf8),
              let response = tuple?.1 as? HTTPURLResponse else {
            logger.error("Failed to fetch data")
            throw CalendarParsingError.invalidCredentials
        }
        if response.statusCode != 200 {
            logger.error("Failed to fetch data: Server returned error code")
            throw CalendarParsingError.invalidCredentials
        }
        
        return string
    }
    
    /// Checks if the user is the current Hausmeister.
    /// - Returns: Returns true if the user is the current Hausmeister, false otherwise.
    func isUserCurrentHausmeister() -> Bool {
        logger.trace("Checking if current user is Hausmeister")
        let optionalAttendee = events.first { event in
            event.startDate <= Date().noon
        }?.attendee
        
        guard let name = model?.name, let attendee = optionalAttendee else {
            return false
        }
        
        return attendee.contains(name)
    }
    
    /// Gets a human readable sentence with informations who is the current Hausmeister.
    /// - Returns: Sentence with informations who is the current Hausmeister.
    func getCurrentHausmeisterAsSentence() -> String {
        logger.trace("Getting current Hausmeister")
        let optionalAttendee = events.first { event in
            event.startDate <= Date().noon
        }?.attendee
        
        guard let attendee = optionalAttendee else {
            return "There is no Hausmeister this week."
        }
        
        return "\(attendee) is Hausmeister this week."
    }
    
    func getWeeksTillNextHausmeister() -> Int {
        guard let name = model?.name else {
            return -1
        }
        let optionalEvent = events.first { event in
            event.attendee.contains(name)
        }
        guard let event = optionalEvent else {
            return -1
        }
        
        let secondsPerWeek: Double = 7 * 24 * 60 * 60
        // We round up, because when there are e.g. just 3 days left till the curent user becomes Hausmeister
        // it is still next week and thus the method should return one.
        let weeksTillHausmeister = (event.startDate.timeIntervalSinceNow / secondsPerWeek).rounded(.up)
        return Int(weeksTillHausmeister)
    }
    
    /// Gets a human readable sentence with information when the user is Hausmeister again.
    /// - Returns: Sentence with information when the user is Hausmeister again.
    func getWeeksTillNextHausmeisterAsSentence() -> String {
        if getWeeksTillNextHausmeister() < 0 {
            return "\(getCurrentHausmeisterAsSentence())\n" +
                "You are not scheduled to be Hausmeister in the next time."
        } else if getWeeksTillNextHausmeister() == 0 {
            return "You are Hausmeister this week."
        } else if getWeeksTillNextHausmeister() == 1 {
            return "\(getCurrentHausmeisterAsSentence())\n" +
                "You are Hausmeister next week."
        } else {
            return "\(getCurrentHausmeisterAsSentence())\n" +
                "In \(getWeeksTillNextHausmeister()) weeks it is your turn again."
        }
    }
    
    /// Checks if data was fetched.
    /// - Returns: Returns true if data was fetched, false otherwise.
    func dataFetched() -> Bool {
        !rawEvents.isEmpty
    }
}

// Based on https://stackoverflow.com/a/44009988
// The fallback ?? Date(timeIntervalSince1970: 0) should never be needed. Calendar.current.date
// only returns nil if the Date in the to attribute is invalid. As we pass self in here, we can be sure
// that the date is valid.
extension Date {
    func addWeeks(_ numberOfWeeks: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: numberOfWeeks * 7, to: self) ??
            Date(timeIntervalSince1970: 0)
    }
    
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self) ??
            Date(timeIntervalSince1970: 0)
    }
    
    func addHours(_ numberOfHours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: numberOfHours, to: self) ??
            Date(timeIntervalSince1970: 0)
    }
}

enum CalendarParsingError: Error {
    case wrongFormat
    case invalidCredentials
}
