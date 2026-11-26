import io

PATH = 'addon/DeathrollBaron/DeathrollBaron.lua'
L = io.open(PATH, encoding='utf-8').read().splitlines()


def body(name, before=2, after=0):
    head = 'function ' + name + '('
    idx = [i for i, l in enumerate(L) if l.startswith(head)]
    if not idx:
        print('MISSING %s' % name)
        return
    for i in idx:
        j = i + 1
        while j < len(L) and L[j] != 'end':
            j += 1
        a, b = max(0, i - before), min(len(L), j + 1 + after)
        print('==== %s  L%d-%d' % (name, a + 1, b))
        for k in range(a, b):
            print('%5d|%s' % (k + 1, L[k]))

for n in ('J.Result', 'J.Settle', 'StartMatch', 'J.Glow'):
    body(n)

print('==== L1960-2034')
for k in range(1959, 2034):
    print('%5d|%s' % (k + 1, L[k]))

print('==== refs')
for i, l in enumerate(L):
    if l.strip().startswith('--'):
        continue
    if 'result' in l or 'J.done' in l or 'ROLL_SPEED' in l:
        print('%5d|%s' % (i + 1, l))
