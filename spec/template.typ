// Rename the project here; the reference code uses "otpdash" / OTPDASH_DB (see chapter "Naming").
#let app = "otpdash"
#let old = "RusTOTPony"

#let note(body) = block(fill: rgb("#e8f1ff"), inset: 8pt, radius: 4pt, width: 100%)[*Rust note.* #body]
#let task(body) = block(stroke: 1pt + rgb("#2a7"), inset: 8pt, radius: 4pt, width: 100%)[*Your turn.* #body]
#let warn(body) = block(fill: rgb("#fff4e0"), inset: 8pt, radius: 4pt, width: 100%)[*Careful.* #body]
#let prompt(body) = block(fill: luma(235), inset: 8pt, radius: 4pt, width: 100%)[*AI prompt.* #emph(body)]

// Pulls a verified source file into the document, so the report and the tested code can't drift apart.
#let source(path, lang: "rust") = raw(read(path), lang: lang, block: true)

// Shows lines of a verified file: from the first line containing `start`, up to (not including)
// the next line containing `until` (or to the end of the file).
#let snippet(path, start, until: none, lang: "rust") = {
  let lines = read(path).split("\n")
  let i = lines.position(l => l.contains(start))
  assert(i != none, message: "snippet start not found: " + start)
  let rest = lines.slice(i)
  let j = if until == none { rest.len() } else {
    let k = rest.slice(1).position(l => l.contains(until))
    assert(k != none, message: "snippet end not found: " + until)
    k + 1
  }
  raw(rest.slice(0, j).join("\n").trim(at: end), lang: lang, block: true)
}

#let setup(doc) = {
  set document(title: app + ": specification and build guide")
  set page(paper: "a4", margin: 2cm, numbering: "1")
  set text(size: 10.5pt)
  set heading(numbering: "1.1")
  set table(inset: 6pt)
  show raw.where(block: true): block.with(fill: luma(245), inset: 8pt, radius: 4pt, width: 100%)
  show heading.where(level: 1): it => { pagebreak(weak: true); it }
  doc
}
