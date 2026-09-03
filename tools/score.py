#!/usr/bin/env python3
"""채운 items.csv에서 §9 지표를 계산한다.

  python3 tools/parse_scene.py scratch/photos/*.jpg --out runs/0902
  # runs/0902/*.items.csv 의 hit / crop 열을 손으로 채운다
  python3 tools/score.py runs/0902/*.items.csv

hit  o=맞음(실재+이름OK)  n=실재하나 이름틀림  x=허위  miss=모델이 놓침
crop o=크롭해서 알아볼 수 있다  x=없다  (miss 행은 비운다)
"""
import argparse, collections, csv, pathlib, sys

# docs/scene-schema.md §9의 합격선. 문서를 고치면 여기도 고친다.
GATES = {
    "재현율":       (0.80, "ge"),
    "라벨 정확도":  (0.60, "ge"),
    "bbox 합격률":  (0.70, "ge"),
    "허위 항목":    (3,    "le"),
    "unknown 비율": (0.15, "le"),
}


def read(path):
    with open(path, encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(l for l in f if not l.startswith("#"))]
    for r in rows:
        r["hit"] = (r.get("hit") or "").strip().lower()
        r["crop"] = (r.get("crop") or "").strip().lower()
    return rows


def score(rows):
    c = collections.Counter(r["hit"] for r in rows)
    real = c["o"] + c["n"]            # 실재하는 물건 중 모델이 잡은 것
    truth = real + c["miss"]          # 실재하는 물건 전체
    crops = [r["crop"] for r in rows if r["hit"] in ("o", "n") and r["crop"] in ("o", "x")]
    unknown = sum(1 for r in rows
                  if r["hit"] in ("o", "n") and r.get("category") == "unknown")
    return {
        "재현율":       real / truth if truth else None,
        "라벨 정확도":  c["o"] / real if real else None,
        "bbox 합격률":  crops.count("o") / len(crops) if crops else None,
        "허위 항목":    c["x"],
        "unknown 비율": unknown / real if real else None,
    }, c, len(crops)


def pad(text, width):
    """한글은 터미널에서 두 칸을 먹는다. 표가 어긋나지 않게 실제 폭으로 맞춘다."""
    import unicodedata
    w = sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in text)
    return text + " " * max(0, width - w)


def render(name, m, c, n_crop):
    print(f"\n[{name}]  잡음 {c['o'] + c['n'] + c['x']}"
          f"  (맞음 {c['o']} / 이름틀림 {c['n']} / 허위 {c['x']})  놓침 {c['miss']}")
    for k, v in m.items():
        gate, direction = GATES[k]
        if v is None:
            print(f"  {pad(k, 16)}—       (판정할 데이터 없음)")
            continue
        ok = v >= gate if direction == "ge" else v <= gate
        shown = f"{v:.0%}" if isinstance(v, float) else str(v)
        want = f"{gate:.0%}" if isinstance(gate, float) else str(gate)
        sign = "≥" if direction == "ge" else "≤"
        print(f"  {pad(k, 16)}{pad(shown, 8)}{'통과' if ok else '미달'}  (합격선 {sign}{want})")
    if not n_crop:
        print("  * crop 열이 비어 있어 bbox 합격률을 재지 못했다")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csvs", nargs="+")
    args = ap.parse_args()

    allrows = []
    for path in args.csvs:
        rows = read(path)
        if not any(r["hit"] for r in rows):
            print(f"[{pathlib.Path(path).stem}] hit 열이 비어 있다. 건너뜀", file=sys.stderr)
            continue
        allrows += rows
        render(pathlib.Path(path).stem, *score(rows))

    if not allrows:
        raise SystemExit("\n채운 CSV가 하나도 없다. hit 열을 먼저 채운다.")
    if len(args.csvs) > 1:
        render("전체", *score(allrows))
    print("\n미달 지표가 있으면 프롬프트를 먼저 고친다. 프롬프트로 안 되면 스키마를 고친다"
          " (scene-schema.md §9).")


if __name__ == "__main__":
    main()
