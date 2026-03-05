import Foundation
import Saga
import SwiftSoup

/// Add `<a name="slug"></a>` anchors to h1, h2, h3 headings.
public func addHeadingAnchors<M>(_ doc: Document, item: Item<M>) throws {
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
public func generateTOC<M>(_ doc: Document, item: Item<M>) throws {
  try _generateTOC(doc, placeholder: "%TOC%")
}

/// Replace a custom placeholder with a generated `<ul class="toc">` from headings.
///
/// Also adds heading anchors, so there is no need to also use ``addHeadingAnchors``.
/// - Parameter placeholder: The placeholder string to look for.
public func generateTOC<M>(placeholder: String) -> (Document, Item<M>) throws -> Void {
  return { doc, _ in
    try _generateTOC(doc, placeholder: placeholder)
  }
}

/// Build a `<ul class="toc">` from h1, h2, h3 headings in the document.
///
/// Also adds heading anchors, so there is no need to also use ``addHeadingAnchors``.
/// Returns `nil` if no headings are found.
///
/// - Parameter placeholder: If provided, only headings after the this
///   placeholder are included. If `nil`, all headings are included.
public func buildTOCList(_ doc: Document, placeholder: String? = nil) throws -> String? {
  var tocEntries: [(text: String, slug: String, level: Int)] = []
  var collecting = placeholder == nil

  let elements = try doc.select(placeholder == nil ? "h1, h2, h3" : "p, h1, h2, h3")
  for element in elements {
    let tagName = element.tagName()
    let text = try element.text()

    if let placeholder, tagName == "p", text == placeholder {
      collecting = true
      continue
    }

    guard tagName != "p" else { continue }

    let slug = text.slugified
    if try element.select("a[name]").isEmpty() {
      try element.prepend("<a name=\"\(slug)\"></a>")
    }

    if collecting {
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

  guard !tocEntries.isEmpty else { return nil }

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

  for _ in 0 ..< currentLevel {
    tocHTML += "</li></ul>"
  }

  let fragment = try SwiftSoup.parseBodyFragment(tocHTML)
  guard let toc = try fragment.select("ul").first() else { return nil }
  try toc.addClass("toc")
  return try toc.outerHtml()
}

func _generateTOC(_ doc: Document, placeholder: String) throws {
  guard let tocParagraph = try doc.select("p").first(where: { try $0.text() == placeholder }) else {
    return
  }

  guard let tocHTML = try buildTOCList(doc, placeholder: placeholder) else {
    try tocParagraph.remove()
    return
  }

  let fragment = try SwiftSoup.parseBodyFragment(tocHTML)
  guard let toc = try fragment.select("ul").first() else { return }
  try tocParagraph.replaceWith(toc)
}

/// Convert blockquotes with `[!TYPE]` syntax to `<aside class="type">` elements.
///
/// For example, a blockquote starting with `[!WARNING]` becomes `<aside class="warning">`.
public func convertAsides<M>(_ doc: Document, item: Item<M>) throws {
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
public func processExternalLinks<M>(_ doc: Document, item: Item<M>) throws {
  let links = try doc.select("a[href]")
  for link in links {
    let href = try link.attr("href")
    if href.hasPrefix("http://") || href.hasPrefix("https://") {
      try _ = link.attr("target", "_blank")
      try _ = link.attr("rel", "nofollow")
    }
  }
}
