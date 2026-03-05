import Saga
import SwiftSoup

/// Combine SwiftSoup transformations into a Saga item processor.
///
/// Parses `item.body` with SwiftSoup once, applies all transformations in order,
/// then serializes back. On error, `item.body` is left unchanged.
///
/// ```swift
/// itemProcessor: swiftSoupProcessor(generateTOC, convertAsides, processExternalLinks)
/// ```
///
/// Can be combined with other item processors using Saga's `sequence()`:
/// ```swift
/// itemProcessor: sequence(
///   swiftSoupProcessor(generateTOC, convertAsides, processExternalLinks),
///   myOtherProcessor
/// )
/// ```
public func swiftSoupProcessor<M>(
  _ transformations: ((Document, Item<M>) throws -> Void)...
) -> (Item<M>) async -> Void {
  return { item in
    do {
      let doc = try SwiftSoup.parseBodyFragment(item.body)
      for transformation in transformations {
        try transformation(doc, item)
      }
      item.body = try doc.body()?.html() ?? item.body
    } catch {
      // On error, leave item.body unchanged
    }
  }
}
