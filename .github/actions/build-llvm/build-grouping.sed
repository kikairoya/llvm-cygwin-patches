h

s/^\[([0-9]+00)\/[0-9]+\].*$/build \1/
tX
s/^.*\(([0-9]+) of \1\)$/test finish/
tXb
s/^.*\(([0-9]+00) of [0-9]+\)$/test \1/
tX
s/^-- Testing: .* tests, .* workers --$/test 0/
tX

s/^\*{20} TEST '([^ ]+) :: ([^']+)' FAILED \*{20}/::error file=\1\/\/\2::TEST \1\/\/\2 FAILED/
tE

1i ::group::build 0
$a ::endgroup::
p; d

:Xb
s/^/::endgroup::\n::group::/
H; x; p; d

:X
s/^/::endgroup::\n::group::/
G; p; d

:E
G; p; d
