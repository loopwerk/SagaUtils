import Foundation

public extension String {
  /// Strip all HTML tags, returning plain text. Keeps code block content.
  var plainText: String {
    replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Strip all HTML tags and code blocks, returning only prose text.
  var textOnly: String {
    replacingOccurrences(of: "(?m)<pre><span></span><code>[\\s\\S]+?</code></pre>", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The number of words in the string.
  var wordCount: Int {
    split { $0.isWhitespace }.count
  }

  /// Truncate the string to a given length.
  ///
  /// See https://jinja2docs.readthedocs.io/en/stable/templates.html#truncate
  func truncate(length: Int = 255, killWords: Bool = false, end: String = "...", leeway: Int = 5) -> String {
    if count <= length + leeway {
      return self
    }

    if killWords {
      return prefix(length - end.count) + end
    }

    return prefix(length - end.count).split(separator: " ").dropLast().joined(separator: " ") + end
  }
}
