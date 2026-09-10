# Visual asset provenance

`banner.svg` is original vector project artwork authored directly in SVG. It contains no external fonts, embedded raster images, scripts, corporate logo, or application screenshot. Its dark navy surfaces and mint accents follow the project's visual direction.

The following filenames are reserved for main-agent-supplied public previews:

| Asset | Required provenance | Status |
| --- | --- | --- |
| `network-lookup.png` | Production Flutter widgets rendered with injected synthetic sample data | Pending |
| `process-manager.png` | Production Flutter widgets rendered with injected synthetic sample data | Pending |

Caption each preview **“Actual Flutter UI rendered with synthetic sample data”**. Record its originating test and app revision when supplied. Inspect the image for legibility and private data before embedding it in README's gallery. Do not replace these files with an illustration or a fabricated screenshot.

These renders do not establish live native-app behavior or Windows manual UI verification. Track those checks separately in [testing.md](../testing.md).
