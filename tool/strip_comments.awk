# Blank out Dart comments while preserving line numbers, so a gate rule's own
# explanation is never reported as an offender. String literals are not
# tracked: stripping slightly too much is the safe direction for these needles,
# because a needle hidden in a string is not the leak the gates exist to catch.
#
# Used by tool/check_bans.sh and tool/check_core_purity.sh. One copy, because
# two copies of a comment stripper is two strippers that will disagree.
BEGIN { inblock = 0 }
{
  line = $0; out = ""; i = 1; n = length(line)
  while (i <= n) {
    two = substr(line, i, 2)
    if (inblock) {
      if (two == "*/") { inblock = 0; i += 2 } else { i++ }
    } else if (two == "/*") {
      inblock = 1; i += 2
    } else if (two == "//") {
      break
    } else {
      out = out substr(line, i, 1); i++
    }
  }
  print out
}
