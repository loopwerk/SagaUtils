import Saga
@testable import SagaUtils
import SwiftSoup
import XCTest

final class SwiftSoupTransformationTests: XCTestCase {
  private let normalize = { (s: String) in
    s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
  }

  // MARK: - addHeadingAnchors

  func testAddHeadingAnchors() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h1>Hello World</h1><h2>Section Two</h2><h3>Sub Section</h3>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <h1><a name="hello-world"></a>Hello World</h1>
    <h2><a name="section-two"></a>Section Two</h2>
    <h3><a name="sub-section"></a>Sub Section</h3>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testAddHeadingAnchorsIgnoresH4AndBelow() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h4>Not Anchored</h4><h5>Also Not</h5>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <h4>Not Anchored</h4>
    <h5>Also Not</h5>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testAddHeadingAnchorsDoesNotAffectInternalLinks() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h2>Title</h2><a href=\"/about\">About</a>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <h2><a name="title"></a>Title</h2>
    <a href="/about">About</a>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testAddHeadingAnchorsSkipsDuplicates() throws {
    let doc = try SwiftSoup.parseBodyFragment("<h2><a name=\"existing\"></a>Title</h2>")
    try addHeadingAnchors(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <h2><a name="existing"></a>Title</h2>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  // MARK: - generateTOC

  func testGenerateTOCNesting() throws {
    let input = "<h2>Before</h2><p>%TOC%</p><h2>Hardware</h2><h3>Computers</h3><h3>Gadgets</h3><h2>Software</h2><h3>Editors</h3><h3>Browsers</h3>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <h2><a name="before"></a>Before</h2>
    <ul class="toc">
     <li><a href="#hardware">Hardware</a>
      <ul>
       <li><a href="#computers">Computers</a></li>
       <li><a href="#gadgets">Gadgets</a></li>
      </ul></li>
     <li><a href="#software">Software</a>
      <ul>
       <li><a href="#editors">Editors</a></li>
       <li><a href="#browsers">Browsers</a></li>
      </ul></li>
    </ul>
    <h2><a name="hardware"></a>Hardware</h2>
    <h3><a name="computers"></a>Computers</h3>
    <h3><a name="gadgets"></a>Gadgets</h3>
    <h2><a name="software"></a>Software</h2>
    <h3><a name="editors"></a>Editors</h3>
    <h3><a name="browsers"></a>Browsers</h3>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testGenerateTOCNestingH1H2H3() throws {
    let input = "<h1>Before</h1><p>%TOC%</p><h1>First</h1><h2>Second</h2><h3>Third</h3>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <h1><a name="before"></a>Before</h1>
    <ul class="toc">
     <li><a href="#first">First</a>
      <ul>
       <li><a href="#second">Second</a>
        <ul>
         <li><a href="#third">Third</a></li>
        </ul></li>
      </ul></li>
    </ul>
    <h1><a name="first"></a>First</h1>
    <h2><a name="second"></a>Second</h2>
    <h3><a name="third"></a>Third</h3>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testGenerateTOCFlatH2Only() throws {
    let input = "<p>%TOC%</p><h2>One</h2><h2>Two</h2><h2>Three</h2>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <ul class="toc">
     <li><a href="#one">One</a></li>
     <li><a href="#two">Two</a></li>
     <li><a href="#three">Three</a></li>
    </ul>
    <h2><a name="one"></a>One</h2>
    <h2><a name="two"></a>Two</h2>
    <h2><a name="three"></a>Three</h2>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testGenerateTOCWithoutPlaceholder() throws {
    let input = "<h1>Title</h1><p>Content</p>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(doc)

    XCTAssertEqual(try doc.select("ul.toc").size(), 0)
  }

  func testGenerateTOCCustomPlaceholder() throws {
    let input = "<p>@TOC</p><h2>Section</h2>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try generateTOC(placeholder: "@TOC")(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <ul class="toc">
     <li><a href="#section">Section</a></li>
    </ul>
    <h2><a name="section"></a>Section</h2>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testGenerateTOCNoDuplicateAnchorsWithAddHeadingAnchors() throws {
    let input = "<p>%TOC%</p><h2>One</h2><h2>Two</h2>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try addHeadingAnchors(doc)
    try generateTOC(doc)

    for heading in try doc.select("h2").array() {
      XCTAssertEqual(try heading.select("a[name]").size(), 1)
    }
  }

  // MARK: - convertAsides

  func testConvertAsides() throws {
    let input = "<blockquote><p>[!WARNING] Be careful</p></blockquote>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <aside class="warning">
     <p class="title">WARNING</p>
     <p>Be careful</p>
    </aside>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testConvertAsidesTwoWordType() throws {
    let input = "<blockquote><p>[!DID YOU KNOW] Something interesting</p></blockquote>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <aside class="did-you-know">
     <p class="title">DID YOU KNOW</p>
     <p>Something interesting</p>
    </aside>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testConvertAsidesLeavesRegularBlockquotes() throws {
    let input = "<blockquote><p>Just a regular quote</p></blockquote>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <blockquote>
     <p>Just a regular quote</p>
    </blockquote>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testConvertAsidesMultipleTypes() throws {
    let input = """
    <blockquote><p>[!NOTE] A note</p></blockquote>
    <blockquote><p>[!TIP] A tip</p></blockquote>
    """
    let doc = try SwiftSoup.parseBodyFragment(input)
    try convertAsides(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <aside class="note">
     <p class="title">NOTE</p>
     <p>A note</p>
    </aside>
    <aside class="tip">
     <p class="title">TIP</p>
     <p>A tip</p>
    </aside>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  // MARK: - processExternalLinks

  func testProcessExternalLinks() throws {
    let input = "<a href=\"https://example.com\">External</a><a href=\"/about\">Internal</a>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try processExternalLinks(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <a href="https://example.com" target="_blank" rel="nofollow">External</a>
    <a href="/about">Internal</a>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testProcessExternalLinksHTTP() throws {
    let input = "<a href=\"http://example.com\">HTTP</a>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try processExternalLinks(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <a href="http://example.com" target="_blank" rel="nofollow">HTTP</a>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
  }

  func testProcessExternalLinksLeavesAnchors() throws {
    let input = "<a href=\"#section\">Anchor</a><a href=\"mailto:test@test.com\">Email</a>"
    let doc = try SwiftSoup.parseBodyFragment(input)
    try processExternalLinks(doc)
    let html = try XCTUnwrap(try doc.body()?.html())

    let expected = """
    <a href="#section">Anchor</a>
    <a href="mailto:test@test.com">Email</a>
    """

    XCTAssertEqual(normalize(html), normalize(expected))
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

    let expected = """
    <h2><a name="title"></a>Title</h2>
    <a href="https://example.com" target="_blank" rel="nofollow">Link</a>
    """

    XCTAssertEqual(normalize(item.body), normalize(expected))
  }
}
