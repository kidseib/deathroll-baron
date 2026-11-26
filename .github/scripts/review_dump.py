import io

PATH = 'addon/DeathrollBaron/DeathrollBaron.lua'
L = io.open(PATH, encoding='utf-8').read().splitlines()


def body(name, before=4, after=1):
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

for n in ('ns.AutoPause', 'ns.AutoTick', 'J.Ceremony', 'J.Pace', 'J.PaceK',
          'J.TickReels', 'J.ReelStart', 'J.ReelSettle', 'J.Deal', 'J.Odds'):
    body(n)

print('==== references')
for i, l in enumerate(L):
    if l.strip().startswith('--'):
        continue
    if any(t in l for t in ('AutoPause', 'J.Ceremony(', 'autoDelay', 'paceBase', 'HOLD')):
        print('%5d|%s' % (i + 1, l))
