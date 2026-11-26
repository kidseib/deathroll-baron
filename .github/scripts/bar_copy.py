import io, sys

LOG = 'CHANGELOG.md'
s = io.open(LOG, encoding='utf-8').read()

old = '''  leaves it. The bar drops zero units (`116g`, not `116g 0s`) and the redundant `YOU`, so the
  longest realistic line - `100% . pays 116g 3s . risk 2,997g . EV -1,900g` at 46 characters -
  fits the 384px bar with room to spare.'''
new = '''  leaves it. The bar drops zero units (`116g`, not `116g 0s`) and the redundant `YOU`, so a
  max-purse Double or Nothing line is 46 characters, and even a copper-bearing wager stays near
  52 - inside the 384px bar with tens of pixels to spare.'''

if s.count(old) != 1:
    print('FAIL changelog: %d' % s.count(old))
    sys.exit(1)
print('ok changelog')
s = s.replace(old, new, 1)

io.open(LOG, 'w', encoding='utf-8', newline='\n').write(s)
print('PATCH OK: changelog %d bytes' % len(s))
