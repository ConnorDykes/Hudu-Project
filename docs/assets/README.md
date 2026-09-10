# Visual asset provenance

`banner.svg` is original vector project artwork authored directly in SVG. It contains no external fonts, embedded raster images, scripts, corporate logo, or application screenshot. Its dark navy surfaces and mint accents follow the project's visual direction.

The following previews were rendered and visually inspected on macOS with Flutter 3.47.2:

| Asset | Originating production-widget test | Source revision |
| --- | --- | --- |
| `network-lookup.png` | `apps/network_lookup/test/screenshots_test.dart` | `35a1f56` |
| `process-manager.png` | `apps/process_manager/test/screenshots_test.dart` | `35a1f56` |

Both images show **actual Flutter UI rendered with synthetic sample data**, using the bundled OFL Inter font and Material icons. They match the corresponding checked-in golden files. The later audit-race and Windows timeout fixes do not alter these macOS fixture states; both golden comparisons were rerun successfully. No live machine identifiers, private network records, or real process history appear in the previews.

These renders do not establish live native-app behavior or Windows manual UI verification. Track those checks separately in [testing.md](../testing.md).
