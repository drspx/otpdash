#import "template.typ": *
#show: setup

#align(center + horizon)[
  #text(28pt, weight: "bold")[🐴 #app]\
  #v(4pt)
  #text(14pt)[A minimal TOTP command-line tool in Rust]\
  #v(4pt)
  #text(11pt)[Specification, design and step-by-step build guide]\
  #v(1cm)
  #text(10pt, fill: luma(100))[Imports #old exports · works alongside #old]
]
#pagebreak()

#outline(depth: 2)

#include "chapters/01-overview.typ"
#include "chapters/02-requirements.typ"
#include "chapters/03-data-formats.typ"
#include "chapters/04-architecture.typ"
#include "chapters/05-build-guide.typ"
#include "chapters/06-testing.typ"
#include "chapters/07-migration.typ"
#include "chapters/08-security.typ"
#include "chapters/09-vibe-coding.typ"
#include "chapters/10-naming.typ"
#include "chapters/11-reference.typ"
