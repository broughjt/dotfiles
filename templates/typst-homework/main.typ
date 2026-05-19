#import "@preview/theorion:0.4.1": *
#import "@preview/curryst:0.6.0": rule, prooftree, rule-set
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#show: show-theorion

#set page(margin: 1in)
#set par(justify: true)

// Uncomment if the font is installed on your system.
// #set text(font: "New Computer Modern", size: 11pt)

#let student = "Jackson Brough"
#let course = "Course Name"
#let assignment = "Homework 1"
#let assignment-date = "Month DD, YYYY"

#let problem(number, body) = proposition(title: "Problem " + str(number))[#body]
#let solution(body) = proof[#body]
#let exercise(number, body) = [
  *Exercise #number*

  #body
]

#align(center, text(size: 18pt, strong(assignment)))

#align(center)[
  #student \
  #course \
  #assignment-date
]

#v(1em)

#problem(1)[
  State the problem here.
]
#solution[
  Write the solution here.

  $
    sum_(i=1)^n i = (n(n + 1)) / 2
  $
]

#exercise("1.1")[
  For CS-style assignments, use exercise headings directly.
]

#problem("2")[
  The `theorion` environments work well for math homework.
]
#proof[
  This is a proof. You can also use `#lemma`, `#theorem`, and `#example`.
]

// `curryst` proof-tree example:
// #align(center)[
//   #prooftree(
//     rule(name: $[var]$, $x : T tack.r x : T$)
//   )
// ]

// `fletcher` diagram example:
// #align(center)[
//   #diagram({
//     node((0, 0), $A$)
//     node((1, 0), $B$)
//     edge((0, 0), (1, 0), $f$)
//   })
// ]
