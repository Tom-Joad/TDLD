# Fonts

Anton (regular) and Archivo (variable weight) as `.woff2`, split by script the
way Google Fonts splits them. `tokens.css` declares each family twice, once per
file, with a `unicode-range`, so a page loads the Latin Extended file only when
it uses a character from it. English and German pages load the Latin files
only. Both licences are SIL Open Font License 1.1 (`OFL-*.txt`).

| File | Covers | Source | Taken | SHA-256 |
| --- | --- | --- | --- | --- |
| `Anton-Regular-latin.woff2` | Latin (English, German) | earlier snapshot, source not recorded | before 2026-11 | `d0fa07ff63dd60cbc0e2f58e29c802dca2a5ae0276c999f59c6111ab7bbaec3b` |
| `Archivo-Variable-latin.woff2` | Latin (English, German) | earlier snapshot, source not recorded | before 2026-11 | `8f704806dbedeaaeca334b11ec348bc3ac3a439d6431544b3afb54f534ee4967` |
| `Anton-Regular-latin-ext.woff2` | Latin Extended: Polish, Turkish, Czech, Romanian, Hungarian and more | `https://fonts.gstatic.com/s/anton/v27/1Ptgg87LROyAm3K9-C8QSw.woff2` (the `latin-ext` face of `https://fonts.googleapis.com/css2?family=Anton`) | 2026-11-10 | `0d17b7880f389deeb6663a52fa4eadc6d9116bdda725f0aa1f3d404fbb7d3d59` |
| `Archivo-Variable-latin-ext.woff2` | the same | `https://fonts.gstatic.com/s/archivo/v25/k3kPo8UDI-1M0wlSV9XAw6lQkqWY8Q82sLyTOxK-vA.woff2` (the `latin-ext` face of `https://fonts.googleapis.com/css2?family=Archivo:wght@400..800`) | 2026-11-10 | `ff4f17d21930e36d6d93baba663e624cb767afc3feebf7adaebd82242638de05` |

Get new files only from the Google Fonts CSS API (fetch the CSS with a current
browser User-Agent so it serves `woff2`, take the face whose comment says
`latin-ext`), never from a third-party mirror.

Checked with fontTools on 2026-11-10: every Polish and Turkish letter is in one of the two files of each family. The unicode-ranges in `tokens.css` are copied from the same Google CSS and must match across both families.
