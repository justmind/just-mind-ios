import XCTest
@testable import JustMind

/// Tests for the clinical math behind the Wellbeing Check-In (WCI) and the
/// deterministic content rotations. These guard against a refactor silently
/// changing scoring, the cutoff/RCI thresholds, or making the daily content
/// non-deterministic.
final class ScoringTests: XCTestCase {

    // MARK: WCI total

    func testTotalIsSumOfFourSubscales() {
        let e = ROSEntry(individual: 2.0, interpersonal: 3.0, social: 4.0, overall: 5.0)
        XCTAssertEqual(e.total, 14.0, accuracy: 0.0001)
    }

    func testTotalFloorAndCeiling() {
        let low = ROSEntry(individual: 0, interpersonal: 0, social: 0, overall: 0)
        XCTAssertEqual(low.total, 0.0, accuracy: 0.0001)

        let high = ROSEntry(individual: 10, interpersonal: 10, social: 10, overall: 10)
        XCTAssertEqual(high.total, ROSEntry.maxTotal, accuracy: 0.0001)
        XCTAssertEqual(ROSEntry.maxTotal, 40.0, accuracy: 0.0001)
    }

    func testOneDecimalPrecisionCarries() {
        let e = ROSEntry(individual: 3.7, interpersonal: 5.7, social: 7.0, overall: 7.7)
        XCTAssertEqual(e.total, 24.1, accuracy: 0.0001)
    }

    // MARK: Clinical thresholds

    func testClinicalCutoffConstant() {
        XCTAssertEqual(ROSEntry.clinicalCutoffAdult, 25.0, accuracy: 0.0001)
    }

    func testReliableChangeIndexConstant() {
        XCTAssertEqual(ROSEntry.reliableChangeIndex, 6.0, accuracy: 0.0001)
    }

    func testAboveAndBelowCutoff() {
        let below = ROSEntry(individual: 6, interpersonal: 6, social: 6, overall: 6) // 24
        let above = ROSEntry(individual: 7, interpersonal: 6, social: 6, overall: 6) // 25
        XCTAssertLessThan(below.total, ROSEntry.clinicalCutoffAdult)
        XCTAssertGreaterThanOrEqual(above.total, ROSEntry.clinicalCutoffAdult)
    }

    func testReliableChangeThreshold() {
        // A 6-point swing should meet the RCI; 5.9 should not.
        XCTAssertGreaterThanOrEqual(abs(31.0 - 25.0), ROSEntry.reliableChangeIndex)
        XCTAssertLessThan(abs(30.9 - 25.0), ROSEntry.reliableChangeIndex)
    }

    // MARK: Deterministic daily content

    func testQuoteIsStableForSameDay() {
        let date = Self.makeDate(year: 2026, month: 4, day: 27)
        XCTAssertEqual(QuoteService.quoteForToday(date), QuoteService.quoteForToday(date))
    }

    func testQuoteAlwaysReturnsFromCuratedList() {
        // Sweep a year of dates; every result must be one of the curated quotes.
        let set = Set(QuoteService.quotes)
        var cursor = Self.makeDate(year: 2026, month: 1, day: 1)
        for _ in 0..<366 {
            XCTAssertTrue(set.contains(QuoteService.quoteForToday(cursor)))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }
    }

    func testPromptIsStableForSameDayAndInList() {
        let date = Self.makeDate(year: 2026, month: 4, day: 27)
        let p = JournalPrompts.promptForToday(date)
        XCTAssertEqual(p, JournalPrompts.promptForToday(date))
        XCTAssertTrue(JournalPrompts.prompts.contains(p))
    }

    // MARK: Helpers

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 9
        return Calendar.current.date(from: c)!
    }
}
