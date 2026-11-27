import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "or J.coinAnim" in src:
    raise SystemExit("already applied")


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        i = src.find(old.splitlines()[0])
        raise SystemExit("%s: %d matches\n%s" % (label, n, repr(src[i:i + 220])))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    '''    if ns.autoT < ns.AutoPause(s) or J.hold then return end''',
    '''    if ns.autoT < ns.AutoPause(s) or J.hold or J.potAnim or J.coinAnim then return end''',
    "auto wait",
)

swap(
    '''    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)''',
    '''    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.30)''',
    "rail alpha",
)

path.write_text(src)
print("patched")
