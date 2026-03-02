@testable import SagaUtils
import XCTest

final class StringExtensionTests: XCTestCase {
  // MARK: - plainText

  func testPlainText() {
    XCTAssertEqual("<p>Hello <strong>world</strong></p>".plainText, "Hello world")
    XCTAssertEqual("plain text".plainText, "plain text")
    XCTAssertEqual("<div><p>Nested</p></div>".plainText, "Nested")
  }

  // MARK: - textOnly

  func testTextOnly() {
    XCTAssertEqual("<p>Hello <strong>world</strong></p>".textOnly, "Hello world")
    XCTAssertEqual("<p>Intro</p><pre><span></span><code>let x = 1</code></pre><p>End</p>".textOnly, "Intro End")
  }

  // MARK: - wordCount

  func testWordCount() {
    XCTAssertEqual("Hello world".wordCount, 2)
    XCTAssertEqual("one".wordCount, 1)
    XCTAssertEqual("".wordCount, 0)
    XCTAssertEqual("  multiple   spaces  ".wordCount, 2)
    XCTAssertEqual("Hello, world! How are you?".wordCount, 5)
    XCTAssertEqual("don't".wordCount, 1)
    XCTAssertEqual("self-contained".wordCount, 1)
  }

  // MARK: - truncate

  func testTruncateShortString() {
    XCTAssertEqual("Hello".truncate(length: 20), "Hello")
  }

  func testTruncateWithLeeway() {
    // "Hello world" (11 chars) is within length (10) + leeway (5) = 15
    XCTAssertEqual("Hello world".truncate(length: 10, leeway: 5), "Hello world")
  }

  func testTruncateAtWordBoundary() {
    let text = "The quick brown fox jumps over the lazy dog"
    XCTAssertEqual(text.truncate(length: 20), "The quick brown...")
  }

  func testTruncateKillWords() {
    let text = "The quick brown fox jumps over the lazy dog"
    XCTAssertEqual(text.truncate(length: 20, killWords: true), "The quick brown f...")
  }

  func testTruncateCustomEnd() {
    let text = "The quick brown fox jumps over the lazy dog"
    XCTAssertEqual(text.truncate(length: 20, killWords: true, end: "…"), "The quick brown fox…")
  }
}
