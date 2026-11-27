import pathlib

lines = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua").read_text().splitlines()
out = []


def show(name, needle, before=6, after=16):
    for i, line in enumerate(lines):
        if needle in line:
            out.append("== %s (line %d) ==" % (name, i + 1))
            for j in range(max(0, i - before), min(len(lines), i + after)):
                out.append("%4d| %s" % (j + 1, lines[j]))
            out.append("")
            return
    out.append("== %s NOT FOUND ==" % name)


show("win log", 'LogLine(s, "win"')
show("lose log", 'LogLine(s, "lose"')
show("sync", "function J.Sync()", 4, 14)
show("result", "function J.Result(s)", 2, 16)

pathlib.Path("tools/ledger_ctx.txt").write_text("\n".join(out))
print("wrote %d lines" % len(out))
