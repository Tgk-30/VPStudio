import Testing
import Foundation
@testable import VPStudio

// MARK: - SRT Parsing Tests

@Suite("SubtitleParser - SRT")
struct SubtitleParserSRTTests {

    @Test func parsesBasicSRTWithMultipleCues() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,500
        Hello world

        2
        00:00:05,000 --> 00:00:08,200
        Second subtitle
        """

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 2)
        #expect(cues[0].id == 1)
        #expect(cues[0].text == "Hello world")
        #expect(abs(cues[0].startTime - 1.0) < 0.001)
        #expect(abs(cues[0].endTime - 3.5) < 0.001)
        #expect(cues[1].id == 2)
        #expect(cues[1].text == "Second subtitle")
        #expect(abs(cues[1].startTime - 5.0) < 0.001)
        #expect(abs(cues[1].endTime - 8.2) < 0.001)
    }

    @Test func parsesMultiLineSubtitleText() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        Line one
        Line two
        Line three
        """

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Line one\nLine two\nLine three")
    }

    @Test func stripsHTMLTagsFromSRTText() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        <i>Italic text</i> and <b>bold</b>
        """

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Italic text and bold")
    }

    @Test func handlesHoursMinutesSecondsMilliseconds() {
        let content = """
        1
        01:30:45,678 --> 02:15:10,123
        Late in the movie
        """

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        let expectedStart = 1.0 * 3600 + 30.0 * 60 + 45.678
        let expectedEnd = 2.0 * 3600 + 15.0 * 60 + 10.123
        #expect(abs(cues[0].startTime - expectedStart) < 0.001)
        #expect(abs(cues[0].endTime - expectedEnd) < 0.001)
    }

    @Test func skipsBlocksWithInvalidFormat() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        Valid cue

        not-a-number
        bad timestamp
        Bad cue

        3
        00:00:05,000 --> 00:00:06,000
        Another valid cue
        """

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 2)
        #expect(cues[0].text == "Valid cue")
        #expect(cues[1].text == "Another valid cue")
    }

    @Test func returnsEmptyArrayForEmptyContent() {
        let cues = SubtitleParser.parseSRT("")
        #expect(cues.isEmpty)
    }

    @Test func returnsEmptyArrayForGarbageContent() {
        let cues = SubtitleParser.parseSRT("this is not a subtitle file at all")
        #expect(cues.isEmpty)
    }

    @Test func handlesCRLFNewlines() {
        let content = "1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\nWorld\r\n"

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 2)
        #expect(cues[0].text == "Hello")
        #expect(cues[1].text == "World")
    }

    @Test func stripsUTF8BOMFromStartOfContent() {
        let content = "\u{feff}1\n00:00:01,000 --> 00:00:02,000\nBOM cue\n"

        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "BOM cue")
    }
}

// MARK: - VTT Parsing Tests

@Suite("SubtitleParser - VTT")
struct SubtitleParserVTTTests {

    @Test func parsesBasicVTTWithHeader() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.500
        First cue

        00:00:05.000 --> 00:00:08.200
        Second cue
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 2)
        #expect(cues[0].text == "First cue")
        #expect(abs(cues[0].startTime - 1.0) < 0.001)
        #expect(abs(cues[0].endTime - 3.5) < 0.001)
        #expect(cues[1].text == "Second cue")
    }

    @Test func parsesVTTWithCueIdentifiers() {
        let content = """
        WEBVTT

        intro
        00:00:01.000 --> 00:00:03.000
        Welcome

        main
        00:00:04.000 --> 00:00:06.000
        Main content
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 2)
        #expect(cues[0].text == "Welcome")
        #expect(cues[1].text == "Main content")
    }

    @Test func stripsHTMLTagsFromVTTText() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        <b>Bold</b> and <i>italic</i>
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Bold and italic")
    }

    @Test func parsesShortTimestampFormat() {
        let content = """
        WEBVTT

        01:23.456 --> 02:34.567
        Short format
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        let expectedStart = 1.0 * 60 + 23.456
        let expectedEnd = 2.0 * 60 + 34.567
        #expect(abs(cues[0].startTime - expectedStart) < 0.001)
        #expect(abs(cues[0].endTime - expectedEnd) < 0.001)
    }

    @Test func returnsEmptyArrayForEmptyVTT() {
        let cues = SubtitleParser.parseVTT("WEBVTT\n\n")
        #expect(cues.isEmpty)
    }

    @Test func handlesCRLFNewlines() {
        let content = "WEBVTT\r\n\r\n00:00:01.000 --> 00:00:02.000\r\nFirst cue\r\n\r\n00:00:02.500 --> 00:00:04.000\r\nSecond cue\r\n"

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 2)
        #expect(cues[0].text == "First cue")
        #expect(abs(cues[1].endTime - 4.0) < 0.001)
    }

    @Test func parsesMultiLineVTTText() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        Line one
        Line two
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Line one\nLine two")
    }

    @Test func preservesLiteralOpenBracketWhenVTTTagIsUnclosed() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        A literal < bracket survives
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "A literal < bracket survives")
    }

    @Test func voiceTagsUseSpeakerNamesAndDropEmptyVoiceTags() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        <v Narrator>Hello</v> <v>world</v>
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "NarratorHello world")
    }

    @Test func interiorBOMIsNormalizedToPrefixForVTTParsing() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        \u{FEFF}Interior BOM
        """

        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text.contains("Interior BOM"))
    }
}

// MARK: - ASS/SSA Parsing Tests

@Suite("SubtitleParser - ASS/SSA")
struct SubtitleParserASSTests {

    @Test func parsesBasicASSDialogueLine() {
        let content = """
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.50,Default,,0,0,0,,Hello from ASS
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Hello from ASS")
        #expect(abs(cues[0].startTime - 1.0) < 0.001)
        #expect(abs(cues[0].endTime - 3.5) < 0.001)
    }

    @Test func stripsASSStyleTags() {
        let content = """
        [Events]
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\\b1}Bold{\\b0} text {\\i1}italic{\\i0}
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Bold text italic")
    }

    @Test func replacesNewlineEscapesInASS() {
        let content = """
        [Events]
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Line one\\NLine two\\nLine three
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Line one\nLine two\nLine three")
    }

    @Test func handlesTextWithCommas() {
        let content = """
        [Events]
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Hello, world, how are you?
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Hello, world, how are you?")
    }

    @Test func parsesMultipleDialogueLines() {
        let content = """
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:05.00,0:00:07.00,Default,,0,0,0,,Second cue
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,First cue
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 2)
        // ASS parser sorts by start time
        #expect(cues[0].text == "First cue")
        #expect(cues[1].text == "Second cue")
    }

    @Test func skipsNonDialogueLines() {
        let content = """
        [Script Info]
        Title: Test
        [V4+ Styles]
        Style: Default,Arial,20,&H00FFFFFF
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Comment: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,This is a comment
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Actual dialogue
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Actual dialogue")
    }

    @Test func returnsEmptyArrayForNoDialogue() {
        let content = """
        [Script Info]
        Title: Empty
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.isEmpty)
    }

    @Test func handlesASSTimestampFormat() {
        // ASS uses H:MM:SS.CS (centiseconds)
        let content = """
        Dialogue: 0,1:30:45.67,2:15:10.12,Default,,0,0,0,,Late in the movie
        """

        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        let expectedStart = 1.0 * 3600 + 30.0 * 60 + 45.67
        let expectedEnd = 2.0 * 3600 + 15.0 * 60 + 10.12
        #expect(abs(cues[0].startTime - expectedStart) < 0.01)
        #expect(abs(cues[0].endTime - expectedEnd) < 0.01)
    }
}

// MARK: - Format Dispatch Tests

@Suite("SubtitleParser - Format Dispatch")
struct SubtitleParserFormatDispatchTests {

    @Test func dispatchesToSRTParser() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        SRT content
        """

        let cues = SubtitleParser.parse(content: content, format: .srt)
        #expect(cues.count == 1)
        #expect(cues[0].text == "SRT content")
    }

    @Test func dispatchesToVTTParser() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        VTT content
        """

        let cues = SubtitleParser.parse(content: content, format: .vtt)
        #expect(cues.count == 1)
        #expect(cues[0].text == "VTT content")
    }

    @Test func dispatchesToASSParser() {
        let content = """
        Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,ASS content
        """

        let cues = SubtitleParser.parse(content: content, format: .ass)
        #expect(cues.count == 1)
        #expect(cues[0].text == "ASS content")
    }

    @Test func dispatchesToASSParserForSSA() {
        let content = """
        Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,SSA content
        """

        let cues = SubtitleParser.parse(content: content, format: .ssa)
        #expect(cues.count == 1)
        #expect(cues[0].text == "SSA content")
    }

    @Test func unknownFormatFallsBackToSRT() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        Fallback SRT
        """

        let cues = SubtitleParser.parse(content: content, format: .unknown)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Fallback SRT")
    }
}

// MARK: - Active Cue Tests

@Suite("SubtitleParser - Active Cue")
struct SubtitleParserActiveCueTests {

    private let testCues = [
        SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 3.0, text: "First"),
        SubtitleParser.SubtitleCue(id: 2, startTime: 5.0, endTime: 8.0, text: "Second"),
        SubtitleParser.SubtitleCue(id: 3, startTime: 10.0, endTime: 12.0, text: "Third"),
    ]

    @Test func findsActiveCueAtExactStartTime() {
        let cue = SubtitleParser.activeCue(at: 1.0, in: testCues)
        #expect(cue?.text == "First")
    }

    @Test func findsActiveCueAtExactEndTime() {
        let cue = SubtitleParser.activeCue(at: 3.0, in: testCues)
        #expect(cue?.text == "First")
    }

    @Test func findsActiveCueMidway() {
        let cue = SubtitleParser.activeCue(at: 6.5, in: testCues)
        #expect(cue?.text == "Second")
    }

    @Test func returnsNilBetweenCues() {
        let cue = SubtitleParser.activeCue(at: 4.0, in: testCues)
        #expect(cue == nil)
    }

    @Test func returnsNilBeforeAllCues() {
        let cue = SubtitleParser.activeCue(at: 0.0, in: testCues)
        #expect(cue == nil)
    }

    @Test func returnsNilAfterAllCues() {
        let cue = SubtitleParser.activeCue(at: 15.0, in: testCues)
        #expect(cue == nil)
    }

    @Test func returnsNilForEmptyCueArray() {
        let cue = SubtitleParser.activeCue(at: 1.0, in: [])
        #expect(cue == nil)
    }

    @Test func zeroDurationCueActiveOnlyAtExactTime() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 5.0, endTime: 5.0, text: "Marker"),
        ]
        let atExact = SubtitleParser.activeCue(at: 5.0, in: cues)
        #expect(atExact?.text == "Marker")

        let justBefore = SubtitleParser.activeCue(at: 4.999, in: cues)
        #expect(justBefore == nil)

        let justAfter = SubtitleParser.activeCue(at: 5.001, in: cues)
        #expect(justAfter == nil)
    }

    @Test func returnsFirstCueWhenMultipleOverlap() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 10.0, text: "First"),
            SubtitleParser.SubtitleCue(id: 2, startTime: 3.0, endTime: 8.0, text: "Second"),
            SubtitleParser.SubtitleCue(id: 3, startTime: 5.0, endTime: 7.0, text: "Third"),
        ]
        let cue = SubtitleParser.activeCue(at: 6.0, in: cues)
        #expect(cue?.id == 1)
        #expect(cue?.text == "First")
    }
}

// MARK: - SRT Edge Cases

@Suite("SubtitleParser - SRT Edge Cases")
struct SubtitleParserSRTEdgeCaseTests {

    @Test func parsesSRTWithEmptyTextBlock() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000

        2
        00:00:03,000 --> 00:00:04,000
        Actual text
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 2)
        #expect(cues[0].text == "")
    }

    @Test func parsesSRTWithWhitespaceOnlyText() {
        let content = "1\n00:00:01,000 --> 00:00:02,000\n   \t  \n\n2\n00:00:03,000 --> 00:00:04,000\nText\n"
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 2)
    }

    @Test func parsesSRTAtZeroTimestamp() {
        let content = """
        1
        00:00:00,000 --> 00:00:02,000
        Start of file
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(abs(cues[0].startTime) < 0.001)
    }

    @Test func parsesSRTWithVeryLargeHoursValue() {
        let content = """
        1
        99:59:59,999 --> 100:00:00,000
        Very long timestamp
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        let expectedStart = 99.0 * 3600 + 59.0 * 60 + 59.999
        #expect(abs(cues[0].startTime - expectedStart) < 0.001)
    }

    @Test func skipsInvalidTimestampFormat() {
        let content = """
        1
        invalid --> timestamp
        Should skip
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.isEmpty)
    }

    @Test func skipsTimestampLineWithoutRequiredArrowSpacing() {
        let content = """
        1
        00:00:01,000-->00:00:02,000
        Missing delimiter spacing
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.isEmpty)
    }

    @Test func skipsTimestampWithoutColonSeparatedComponents() {
        let content = """
        1
        1.000 --> 2.000
        Missing minute component
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.isEmpty)
    }

    @Test func skipsWhenTimestampEndBeforeStart() {
        let content = """
        1
        00:00:05,000 --> 00:00:01,000
        Invalid range
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].startTime < cues[0].endTime)
    }

    @Test func parsesSRTWithMissingCommaInTimestamp() {
        let content = """
        1
        00:00:01.000 --> 00:00:03.000
        Uses dots instead of commas
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(abs(cues[0].startTime - 1.0) < 0.001)
    }
}

// MARK: - VTT Edge Cases

@Suite("SubtitleParser - VTT Edge Cases")
struct SubtitleParserVTDutchCaseTests {

    @Test func parsesVTTWithPositioningSettings() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000 line:50% position:50%
        Positioned subtitle
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Positioned subtitle")
    }

    @Test func parsesVTTWithAlignSettings() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000 align:center
        Centered subtitle
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Centered subtitle")
    }

    @Test func parsesVTTWithVoiceSpans() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        <v Speaker>Text with voice</v>
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "SpeakerText with voice")
    }

    @Test func parsesVTTWithLanguageSpans() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        <lang en>English text</lang>
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "English text")
    }

    @Test func parsesVTTWithTimestampSpans() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        Text <00:00:01.500>with timestamp</00:00:02.000>
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text.contains("with timestamp"))
    }

    @Test func parsesVTTNoteBlockIsIgnored() {
        let content = """
        WEBVTT

        NOTE This is a comment block

        00:00:01.000 --> 00:00:03.000
        Actual subtitle
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Actual subtitle")
    }

    @Test func parsesVTTWithNoHeader() {
        let content = """
        00:00:01.000 --> 00:00:03.000
        No WEBVTT header
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "No WEBVTT header")
    }

    @Test func parsesVTTWithOnlyHeaderAndEmpty() {
        let cues = SubtitleParser.parseVTT("WEBVTT")
        #expect(cues.isEmpty)
    }

    @Test func parsesVTTMultipleBlocks() {
        let content = """
        WEBVTT

        intro
        00:00:00.500 --> 00:00:02.000
        Introduction

        00:00:02.500 --> 00:00:05.000
        Second block

        third-cue
        00:00:06.000 --> 00:00:08.000
        Third block
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 3)
    }

    @Test func swapsReversedVTTTimestamps() {
        let content = """
        WEBVTT

        00:00:05.000 --> 00:00:01.000
        Reversed cue
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
        #expect(abs(cues[0].startTime - 1.0) < 0.001)
        #expect(abs(cues[0].endTime - 5.0) < 0.001)
    }

    @Test func skipsVTTWhenEndTimestampIsOnlySettings() {
        let content = """
        WEBVTT

        00:00:01.000 --> align:center
        Missing end timestamp
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.isEmpty)
    }
}

// MARK: - ASS/SSA Edge Cases

@Suite("SubtitleParser - ASS/SSA Edge Cases")
struct SubtitleParserASSEdgeCaseTests {

    @Test func parsesASSOverlappingDialoguesSortedByTime() {
        let content = """
        [Events]
        Dialogue: 0,0:00:05.00,0:00:10.00,Default,,0,0,0,,Later dialogue
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Earlier dialogue
        Dialogue: 0,0:00:03.00,0:00:05.00,Default,,0,0,0,,Middle dialogue
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 3)
        #expect(cues[0].text == "Earlier dialogue")
        #expect(cues[1].text == "Middle dialogue")
        #expect(cues[2].text == "Later dialogue")
    }

    @Test func parsesASSWithEmptyTextField() {
        let content = """
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "")
    }

    @Test func parsesASSWithTextContainingNewlines() {
        let content = """
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Line 1\\NLine 2\\NLine 3
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Line 1\nLine 2\nLine 3")
    }

    @Test func parsesASSWithDrawCommandsInText() {
        let content = """
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Normal text {\\p0}after draw
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Normal text after draw")
    }

    @Test func parsesASSWithClipping() {
        let content = """
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\\clip(100,100,200,200)}Clipped text
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Clipped text")
    }

    @Test func skipsMalformedASSDialogueWithFewerThanTenFields() {
        let content = """
        [Events]
        Dialogue: 0,0:00:01.00,0:00:03.00,Default
        Dialogue: 0,0:00:05.00,0:00:07.00,Default,,0,0,0,,Valid dialogue
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Valid dialogue")
    }

    @Test func parsesASSDialogueWithNegativeTimes() {
        let content = """
        Dialogue: 0,-0:00:01.00,0:00:03.00,Default,,0,0,0,,Negative start
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 0)
    }

    @Test func handlesMixedNewlinesInASS() {
        let content = "Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,First\r\nDialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,Second"
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 2)
    }

    @Test func swapsReversedASSTimestamps() {
        let content = """
        Dialogue: 0,0:00:05.00,0:00:01.00,Default,,0,0,0,,Reversed ASS
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(abs(cues[0].startTime - 1.0) < 0.001)
        #expect(abs(cues[0].endTime - 5.0) < 0.001)
    }

    @Test func skipsASSDialogueWithInvalidEndTime() {
        let content = """
        Dialogue: 0,0:00:01.00,bad-end,Default,,0,0,0,,Invalid end
        Dialogue: 0,0:00:02.00,0:00:03.00,Default,,0,0,0,,Valid end
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Valid end")
    }
}

// MARK: - Active Cue Edge Cases

@Suite("SubtitleParser - Active Cue Edge Cases")
struct SubtitleParserActiveCueEdgeCaseTests {

    @Test func returnsFirstMatchingOfOverlappingCues() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 5.0, text: "First"),
            SubtitleParser.SubtitleCue(id: 2, startTime: 2.0, endTime: 4.0, text: "Second"),
        ]
        let cue = SubtitleParser.activeCue(at: 3.0, in: cues)
        #expect(cue?.id == 1)
    }

    @Test func handlesConsecutiveCuesWithoutGap() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 3.0, text: "First"),
            SubtitleParser.SubtitleCue(id: 2, startTime: 3.0, endTime: 5.0, text: "Second"),
        ]
        #expect(SubtitleParser.activeCue(at: 3.0, in: cues)?.id == 1)
    }

    @Test func handlesLargeNumberOfCues() {
        var cues: [SubtitleParser.SubtitleCue] = []
        for i in 0..<100 {
            cues.append(SubtitleParser.SubtitleCue(
                id: i,
                startTime: Double(i),
                endTime: Double(i) + 1.0,
                text: "Cue \(i)"
            ))
        }
        let cue = SubtitleParser.activeCue(at: 50.5, in: cues)
        #expect(cue?.id == 50)
    }

    @Test func returnsLastCueAtExactEndTime() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 3.0, text: "First"),
            SubtitleParser.SubtitleCue(id: 2, startTime: 3.0, endTime: 5.0, text: "Second"),
        ]
        let atEnd = SubtitleParser.activeCue(at: 5.0, in: cues)
        #expect(atEnd?.id == 2)
    }

    @Test func handlesCueSpanningEntireRange() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 0.0, endTime: Double.infinity, text: "Infinite"),
        ]
        let cue = SubtitleParser.activeCue(at: 1000000.0, in: cues)
        #expect(cue?.text == "Infinite")
    }

    @Test func returnsNilForNegativeTime() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 3.0, text: "First"),
        ]
        let cue = SubtitleParser.activeCue(at: -1.0, in: cues)
        #expect(cue == nil)
    }

    @Test func handlesUnsortedCues() {
        let cues = [
            SubtitleParser.SubtitleCue(id: 2, startTime: 10.0, endTime: 12.0, text: "Second"),
            SubtitleParser.SubtitleCue(id: 1, startTime: 1.0, endTime: 3.0, text: "First"),
        ]
        let cue = SubtitleParser.activeCue(at: 2.0, in: cues)
        #expect(cue?.id == 1)
    }
}

// MARK: - SubtitleCue Identifiable Conformance

@Suite("SubtitleCue Identifiable")
struct SubtitleCueIdentifiableTests {
    @Test func subtitleCueIdMatchesIdProperty() {
        let cue = SubtitleParser.SubtitleCue(id: 42, startTime: 1.0, endTime: 3.0, text: "Test")
        #expect(cue.id == 42)
        #expect(cue.id == cue.id)
    }
}
