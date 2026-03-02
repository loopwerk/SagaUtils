# SagaUtils

A collection of utilities for [Saga](https://github.com/loopwerk/Saga): HTML transformations and useful String extensions.

## Usage
Include `SagaUtils` in your Package.swift:

```swift
let package = Package(
  dependencies: [
    .package(url: "https://github.com/loopwerk/Saga", from: "2.0.3"),
    .package(url: "https://github.com/loopwerk/SagaUtils", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "MyWebsite",
      dependencies: ["Saga", "SagaUtils"]),
  ]
)
```

## HTML Transformations

SagaUtils provides composable HTML transformations powered by [SwiftSoup](https://github.com/scinfu/SwiftSoup). Each transformation operates on a SwiftSoup `Document` and can be combined using `swiftSoupProcessor`:

```swift
import SagaUtils

try await Saga(input: "content", output: "deploy")
  .register(
    folder: "articles",
    metadata: ArticleMetadata.self,
    readers: [.parsleyMarkdownReader],
    itemProcessor: swiftSoupProcessor(generateTOC, convertAsides, processExternalLinks, addCodeBlockTitles),
    writers: [.itemWriter(swim(renderArticle))]
  )
  .run()
```

### Available Transformations

- **`addHeadingAnchors`** — Adds `<a name="slug"></a>` anchors to h1, h2, h3 headings.
- **`generateTOC`** — Replaces a `%TOC%` placeholder with a `<nav class="toc">` generated from headings. Also adds heading anchors, so there's no need to also use `addHeadingAnchors`. Use `generateTOC(placeholder: "@TOC")` for a custom placeholder.
- **`convertAsides`** — Converts blockquotes with `[!TYPE]` syntax to `<aside class="type">` elements. For example, `[!WARNING]` becomes `<aside class="warning">`.
- **`processExternalLinks`** — Adds `target="_blank"` and `rel="nofollow"` to external links.

You can also write your own transformations with the signature `(Document) throws -> Void` and pass them to `swiftSoupProcessor`.

## String Extensions

Useful extensions on `String`:

```swift
// Strip HTML tags, keeping code block content
"<p>Hello <strong>world</strong></p>".plainText // "Hello world"

// Strip HTML tags and code blocks (useful for word counting)
body.textOnly

// Count words
body.textOnly.wordCount

// Truncate with word boundary awareness (inspired by Jinja2)
text.truncate(length: 200)
text.truncate(length: 200, killWords: true, end: "…")
```
