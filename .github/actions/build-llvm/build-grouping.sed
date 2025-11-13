#!/usr/bin/env -S sed -uE -f

# CMake shows compile errors next after '[nnn/NNN] Building...' with a heading 'FAILED:'.
/^FAILED: \[/bG

h

1i\
::group::build 0

/^-- Testing: .* tests, .* workers --$/{
  i\
::endgroup::\n::group::test 0
}

s/^ *\[([0-9]*[02468]00)\/[0-9]+\].*$/::endgroup::\n::group::build \1/p; g
s/^.*\(([0-9]*[05]00) of [0-9]+\)$/::endgroup::\n::group::test \1/p; g

/^.*\(([0-9]+) of \1\)$/{
  a\
::endgroup::\n::group::test finish
}

$a\
::endgroup::

# Lit shows test failures with certain headings instead of 'PASS:'.
/^(FAIL|XPASS|UNRESOLVED|TIMEOUT): [^\n]*::/{
  $bE1
  # Lit shows details of the error with heading '********************'.
  n; /^\*+ /bF
  # Lit may omit details of the error.
  x; bE1
}

b

# Redirect errors to the '::error' command.
# The hold space contains error dumps except the last line
# The pattern space holds the last line.
:E
H; n; x

# Another pattern to error redirector.
# The hold space holds text from the input, which needs to be just printed.
# The pattern space holds whole the error dumps.
:E1
s/::/%3A%3A/g
s/\n/%0A/g
s/^/::error ::/p
G; D

# Lit concludes to show errors with '********************'.
:F
H; n
/^\*+$/bE
bF

# CMake concludes to show compile errors with 'N error generated.'
:G
H; n
/^[0-9]+ error generated\.$/bE
bG
