import Foundation
import SwiftSoup

/// Add `<a name="slug"></a>` anchors to h1, h2, h3 headings.
public func addHeadingAnchors(_ doc: Document) throws {
  let headings = try doc.select("h1, h2, h3")
  for heading in headings {
    guard try heading.select("a[name]").isEmpty() else { continue }
    let text = try heading.text()
    let slug = text.slugified
    try heading.prepend("<a name=\"\(slug)\"></a>")
  }
}

/// Replace `%TOC%` placeholder with a generated `<ul class="toc">` from headings.
///
/// Also adds heading anchors, so there is no need to also use ``addHeadingAnchors``.
public func generateTOC(_ doc: Document) throws {
  try _generateTOC(doc, placeholder: "%TOC%")
}

/// Replace a custom placeholder with a generated `<ul class="toc">` from headings.
///
/// Also adds heading anchors, so there is no need to also use ``addHeadingAnchors``.
/// - Parameter placeholder: The placeholder string to look for.
public func generateTOC(placeholder: String) -> (Document) throws -> Void {
  return { doc in
    try _generateTOC(doc, placeholder: placeholder)
  }
}

func _generateTOC(_ doc: Document, placeholder: String) throws {
  // Find the <p> containing the placeholder
  guard let tocParagraph = try doc.select("p").first(where: { try $0.text() == placeholder }) else {
    // No placeholder found
    return
  }

  // Collect all headings that appear after the TOC placeholder
  var tocEntries: [(text: String, slug: String, level: Int)] = []
  var foundToc = false

  let elements = try doc.select("p, h1, h2, h3")
  for element in elements {
    let tagName = element.tagName()
    let text = try element.text()

    if tagName == "p", text == placeholder {
      foundToc = true
      continue
    }

    guard tagName != "p" else { continue }

    let slug = text.slugified
    if try element.select("a[name]").isEmpty() {
      try element.prepend("<a name=\"\(slug)\"></a>")
    }

    if foundToc {
      let level: Int
      switch tagName {
        case "h1": level = 1
        case "h2": level = 2
        case "h3": level = 3
        default: continue
      }
      tocEntries.append((text: text, slug: slug, level: level))
    }
  }

  // Build the TOC list
  guard !tocEntries.isEmpty else {
    try tocParagraph.remove()
    return
  }

  // Build nested list HTML
  let minLevel = tocEntries.map(\.level).min() ?? 1
  var tocHTML = ""
  var currentLevel = 0

  for entry in tocEntries {
    let level = entry.level - minLevel + 1

    if level > currentLevel {
      for _ in currentLevel ..< level {
        tocHTML += "<ul>"
      }
    } else if level < currentLevel {
      for _ in level ..< currentLevel {
        tocHTML += "</li></ul>"
      }
      tocHTML += "</li>"
    } else if currentLevel > 0 {
      tocHTML += "</li>"
    }
    currentLevel = level
    tocHTML += "<li><a href=\"#\(entry.slug)\">\(entry.text)</a>"
  }

  // Close remaining open items and lists
  for _ in 0 ..< currentLevel {
    tocHTML += "</li></ul>"
  }

  let fragment = try SwiftSoup.parseBodyFragment(tocHTML)
  guard let toc = try fragment.select("ul").first() else { return }
  try toc.addClass("toc")
  try tocParagraph.replaceWith(toc)
}

/// Convert blockquotes with `[!TYPE]` syntax to `<aside class="type">` elements.
///
/// For example, a blockquote starting with `[!WARNING]` becomes `<aside class="warning">`.
public func convertAsides(_ doc: Document) throws {
  let alertRegex = try NSRegularExpression(pattern: #"^\[!([A-Z][A-Z ]*[A-Z]|[A-Z])\]\s*(?:<br\s*/?>)?\s*"#)
  let blockquotes = try doc.select("blockquote")
  for blockquote in blockquotes {
    guard let firstP = try blockquote.select("p").first() else { continue }
    let text = try firstP.html()

    guard let match = alertRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let typeRange = Range(match.range(at: 1), in: text) else { continue }

    let alertType = String(text[typeRange]).slugified

    // Remove the [!TYPE] marker from the first paragraph
    let cleanedText = alertRegex.stringByReplacingMatches(
      in: text,
      range: NSRange(text.startIndex..., in: text),
      withTemplate: ""
    )
    try firstP.html(cleanedText)

    // Create aside element and replace blockquote
    let aside = try doc.createElement("aside")
    try aside.addClass(alertType)
    let title = String(text[typeRange])
    try aside.html("<p class='title'>\(title)</p>" + (blockquote.html()))
    try blockquote.replaceWith(aside)
  }
}

/// Add `target="_blank"` and `rel="nofollow"` to external (http/https) links.
public func processExternalLinks(_ doc: Document) throws {
  let links = try doc.select("a[href]")
  for link in links {
    let href = try link.attr("href")
    if href.hasPrefix("http://") || href.hasPrefix("https://") {
      try _ = link.attr("target", "_blank")
      try _ = link.attr("rel", "nofollow")
    }
  }
}
