# Blank out Dart COMMENTS while preserving line numbers and, critically, string
# literals — an import URI is a string, so stripping strings would disarm every
# import rule the gates exist to enforce.
#
# Used by tool/check_bans.sh and tool/check_core_purity.sh. One copy, because two
# copies of a comment stripper is two strippers that will disagree.
#
# String tracking is not decoration. Treating `/*` inside a string as a
# block-comment opener leaves `inblock` set with no closer in sight, which blanks
# every remaining line of the file and silently switches the gates off from that
# point on — the unsafe direction. `const p = '/*';` is a real thing a later epic
# writes (a glob, a RegExp source, an ARB pattern).
#
# Handled: `//`, `/* … */` across lines, `'…'`, `"…"`, `'''…'''`, `"""…"""`
# across lines, backslash escapes, and `r`-prefixed raw strings (where a
# backslash escapes nothing).
BEGIN {
  inblock = 0      # inside /* … */
  instr = ""       # the open delimiter: "'", "\"", "'''" or "\"\"\""
  israw = 0        # the open string is r'…'
}
{
  line = $0; out = ""; i = 1; n = length(line)
  while (i <= n) {
    one = substr(line, i, 1)
    two = substr(line, i, 2)
    three = substr(line, i, 3)

    if (inblock) {
      if (two == "*/") { inblock = 0; i += 2 } else { i++ }
      continue
    }

    if (instr != "") {
      # Inside a string: emit it verbatim so import URIs stay matchable.
      len = length(instr)
      if (!israw && one == "\\") {
        out = out substr(line, i, 2); i += 2; continue
      }
      if (substr(line, i, len) == instr) {
        out = out instr; instr = ""; israw = 0; i += len; continue
      }
      out = out one; i++
      continue
    }

    if (two == "//") break
    if (two == "/*") { inblock = 1; i += 2; continue }

    if (three == "'''" || three == "\"\"\"") {
      instr = three
      israw = (i > 1 && substr(line, i - 1, 1) == "r")
      out = out three; i += 3; continue
    }
    if (one == "'" || one == "\"") {
      instr = one
      israw = (i > 1 && substr(line, i - 1, 1) == "r")
      out = out one; i++; continue
    }

    out = out one; i++
  }

  # A single-line string cannot span a newline in Dart. If one is still open the
  # source is malformed; closing it here keeps the next line honest instead of
  # swallowing it.
  if (instr == "'" || instr == "\"") { instr = ""; israw = 0 }

  print out
}
