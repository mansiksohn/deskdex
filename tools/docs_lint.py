#!/usr/bin/env python3
"""문서 lint — AGENTS.md §3의 문서 규칙 중 기계로 확인할 수 있는 것.

  python3 tools/docs_lint.py

- docs/CURRENT.md는 300줄 이하
- docs/DECISIONS.md 각 항목: 제목 `### YYYY-MM-DD 제목`, `- 결정:`·`- 이유:` 필수, 본문 10줄 이하
- 루트·docs·ios의 .md에 있는 상대 링크가 실제 파일을 가리킨다
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors = []

current = ROOT / "docs" / "CURRENT.md"
n = len(current.read_text(encoding="utf-8").splitlines())
if n > 300:
    errors.append(f"docs/CURRENT.md가 {n}줄이다(300줄 이하). 세부는 다른 문서로 옮기고 링크한다")

dec = (ROOT / "docs" / "DECISIONS.md").read_text(encoding="utf-8")
log = dec.split("\n## 기록", 1)
if len(log) != 2:
    errors.append("docs/DECISIONS.md에 '## 기록' 절이 없다")
else:
    for block in re.split(r"\n(?=### )", log[1])[1:]:
        lines = block.strip().splitlines()
        title, body = lines[0], [l for l in lines[1:] if l.strip()]
        if not re.match(r"^### \d{4}-\d{2}-\d{2} \S", title):
            errors.append(f"DECISIONS 제목 형식: {title!r} (### YYYY-MM-DD 제목)")
        for key in ("- 결정:", "- 이유:"):
            if not any(l.startswith(key) for l in body):
                errors.append(f"DECISIONS {title!r}에 '{key}'가 없다")
        if len(body) > 10:
            errors.append(f"DECISIONS {title!r} 본문이 {len(body)}줄이다(10줄 이하)")

LINK = re.compile(r"\]\(([^)\s#]+)(?:#[^)]*)?\)")
for md in [*ROOT.glob("*.md"), *(ROOT / "docs").glob("*.md"), *(ROOT / "ios").glob("*.md")]:
    text = re.sub(r"```.*?```", "", md.read_text(encoding="utf-8"), flags=re.S)
    for target in LINK.findall(text):
        if re.match(r"^[a-z]+:", target):
            continue
        if not (md.parent / target).exists():
            errors.append(f"{md.relative_to(ROOT).as_posix()}: 깨진 링크 {target}")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("docs lint OK")
