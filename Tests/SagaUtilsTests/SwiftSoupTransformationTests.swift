import Saga
@testable import SagaUtils
import SwiftSoup
import XCTest

final class SwiftSoupTransformationTests: XCTestCase {
  // MARK: - addHeadingAnchors

  func testAddHeadingAnchors() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h1>Hello World</h1><h2>Section Two</h2><h3>Sub Section</h3>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertTrue(html.contains("<a name=\"hello-world\"></a>"))
    XCTAssertTrue(html.contains("<a name=\"section-two\"></a>"))
    XCTAssertTrue(html.contains("<a name=\"sub-section\"></a>"))
  }

  func testAddHeadingAnchorsIgnoresH4AndBelow() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h4>Not Anchored</h4><h5>Also Not</h5>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertFalse(html.contains("<a name="))
  }

  func testAddHeadingAnchorsDoesNotAffectInternalLinks() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h2>Title</h2><a href=\"/about\">About</a>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertTrue(html.contains("<a href=\"/about\">About</a>"))
    XCTAssertTrue(html.contains("<a name=\"title\"></a>"))
  }

  // MARK: - generateTOC

  func testGenerateTOC() throws {
    let input = "<p>%TOC%</p><h1>First</h1><h2>Second</h2><h3>Third</h3>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    // TOC placeholder should be replaced
    XCTAssertFalse(html.contains("%TOC%"))

    // Should have a nav.toc
    let nav = try doc.select("nav.toc")
    XCTAssertEqual(nav.size(), 1)

    // Should have links to headings
    let tocLinks = try nav.select("a[href]")
    XCTAssertEqual(tocLinks.size(), 3)
    XCTAssertEqual(try tocLinks.get(0).attr("href"), "#first")
    XCTAssertEqual(try tocLinks.get(1).attr("href"), "#second")
    XCTAssertEqual(try tocLinks.get(2).attr("href"), "#third")

    // Headings should have anchors
    XCTAssertTrue(html.contains("<a name=\"first\"></a>"))
    XCTAssertTrue(html.contains("<a name=\"second\"></a>"))
    XCTAssertTrue(html.contains("<a name=\"third\"></a>"))
  }

  func testGenerateTOCOnlyIncludesHeadingsAfterPlaceholder() throws {
    let input = "<h2>Before</h2><p>%TOC%</p><h2>After</h2>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let tocLinks = try doc.select("nav.toc a[href]")
    XCTAssertEqual(tocLinks.size(), 1)
    XCTAssertEqual(try tocLinks.get(0).attr("href"), "#after")

    // Both headings still get anchors
    XCTAssertTrue(html.contains("<a name=\"before\"></a>"))
    XCTAssertTrue(html.contains("<a name=\"after\"></a>"))
  }

  func testGenerateTOCWithoutPlaceholder() throws {
    let input = "<h1>Title</h1><p>Content</p>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    // No nav should be generated
    XCTAssertEqual(try doc.select("nav.toc").size(), 0)
  }

  func testGenerateTOCCustomPlaceholder() throws {
    let input = "<p>@TOC</p><h2>Section</h2>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(placeholder: "@TOC")(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertFalse(html.contains("@TOC"))
    XCTAssertEqual(try doc.select("nav.toc a[href]").size(), 1)
  }

  // MARK: - convertAsides

  func testConvertAsides() throws {
    let input = "<blockquote><p>[!WARNING] Be careful</p></blockquote>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertFalse(html.contains("<blockquote>"))
    XCTAssertTrue(html.contains("<aside class=\"warning\">"))
    XCTAssertTrue(html.contains("<p class=\"title\">WARNING</p>"))
    XCTAssertTrue(html.contains("Be careful"))
  }

  func testConvertAsidesTwoWordType() throws {
    let input = "<blockquote><p>[!DID YOU KNOW] Something interesting</p></blockquote>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertFalse(html.contains("<blockquote>"))
    XCTAssertTrue(html.contains("<aside class=\"did-you-know\">"))
    XCTAssertTrue(html.contains("<p class=\"title\">DID YOU KNOW</p>"))
    XCTAssertTrue(html.contains("Something interesting"))
  }

  func testConvertAsidesLeavesRegularBlockquotes() throws {
    let input = "<blockquote><p>Just a regular quote</p></blockquote>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertTrue(html.contains("<blockquote>"))
    XCTAssertFalse(html.contains("<aside"))
  }

  func testConvertAsidesMultipleTypes() throws {
    let input = """
    <blockquote><p>[!NOTE] A note</p></blockquote>
    <blockquote><p>[!TIP] A tip</p></blockquote>
    """
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    XCTAssertTrue(html.contains("<aside class=\"note\">"))
    XCTAssertTrue(html.contains("<aside class=\"tip\">"))
  }

  // MARK: - processExternalLinks

  func testProcessExternalLinks() throws {
    let input = "<a href=\"https://example.com\">External</a><a href=\"/about\">Internal</a>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try processExternalLinks(doc)

    let links = try doc.select("a")
    let external = links.get(0)
    let internal_ = links.get(1)

    XCTAssertEqual(try external.attr("target"), "_blank")
    XCTAssertEqual(try external.attr("rel"), "nofollow")
    XCTAssertEqual(try internal_.attr("target"), "")
    XCTAssertEqual(try internal_.attr("rel"), "")
  }

  func testProcessExternalLinksHTTP() throws {
    let input = "<a href=\"http://example.com\">HTTP</a>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try processExternalLinks(doc)

    let link = try XCTUnwrap(try doc.select("a").first())
    XCTAssertEqual(try link.attr("target"), "_blank")
    XCTAssertEqual(try link.attr("rel"), "nofollow")
  }

  func testProcessExternalLinksLeavesAnchors() throws {
    let input = "<a href=\"#section\">Anchor</a><a href=\"mailto:test@test.com\">Email</a>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try processExternalLinks(doc)

    let links = try doc.select("a")
    for link in links {
      XCTAssertEqual(try link.attr("target"), "")
    }
  }

  // MARK: - swiftSoupProcessor combiner

  func testProcessHTMLCombiner() async {
    let item = Item<EmptyMetadata>(
      title: "Test",
      body: "<h2>Title</h2><a href=\"https://example.com\">Link</a>",
      metadata: EmptyMetadata()
    )

    let processor: (Item<EmptyMetadata>) async -> Void = swiftSoupProcessor(addHeadingAnchors, processExternalLinks)
    await processor(item)

    XCTAssertTrue(item.body.contains("<a name=\"title\"></a>"))
    XCTAssertTrue(item.body.contains("target=\"_blank\""))
  }
}
