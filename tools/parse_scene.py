#!/usr/bin/env python3
"""장면 파싱 검증 러너.

스키마와 프롬프트를 docs/scene-schema.md에서 직접 읽는다. 문서가 단일
출처이고, 스크립트가 문서와 어긋날 수 없다.

  pip install anthropic pillow
  export ANTHROPIC_API_KEY=...
  python3 tools/parse_scene.py photos/*.jpg --out runs/2026-08-30

각 사진에 대해:
  <out>/<이름>.raw.json        VLM 원본 응답
  <out>/<이름>.items.csv       정답 대조용. hit 열을 손으로 채운다
  <out>/summary.txt            항목 수, unknown 비율, 후처리에서 버린 수
"""
import argparse, base64, io, json, os, pathlib, re, sys

DOC = pathlib.Path(__file__).resolve().parent.parent / "docs" / "scene-schema.md"
MODEL = "claude-opus-5"


def load_contract():
    """문서에서 스키마(첫 json 블록)와 프롬프트(첫 text 블록)를 꺼낸다."""
    md = DOC.read_text(encoding="utf-8")
    schema = json.loads(re.search(r"```json\n(.*?)```", md, re.S).group(1))
    prompt = re.search(r"```text\n(.*?)```", md, re.S).group(1).strip()
    return schema, prompt


def load_image(path):
    """EXIF orientation을 픽셀에 적용한 뒤 JPEG 바이트로 돌려준다.

    회전이 남아 있으면 좌표 규약과 zone이 통째로 틀어진다 (scene-schema.md §5).
    """
    from PIL import Image, ImageOps

    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    img.thumbnail((1568, 1568))  # 긴 변 기준. 이보다 크면 서버가 어차피 줄인다
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return base64.standard_b64encode(buf.getvalue()).decode()


def call(client, schema, prompt, b64):
    resp = client.messages.create(
        model=MODEL,
        max_tokens=16000,
        system=prompt,
        output_config={"format": schema},
        messages=[{
            "role": "user",
            "content": [
                {"type": "image",
                 "source": {"type": "base64", "media_type": "image/jpeg", "data": b64}},
                {"type": "text", "text": "이 책상 사진을 분석하라."},
            ],
        }],
    )
    if resp.stop_reason == "max_tokens":
        sys.stderr.write("  경고: max_tokens에 닿았다. JSON이 잘렸을 수 있다\n")
    if resp.stop_reason == "refusal":
        raise SystemExit("  거부됨: %s" % resp.stop_details)
    text = "".join(b.text for b in resp.content if b.type == "text")
    return json.loads(text), resp.usage


def area(b):
    return max(0.0, b["x1"] - b["x0"]) * max(0.0, b["y1"] - b["y0"])


def overlap_ratio(item, region):
    """item이 region에 잡아먹힌 비율. 화면 오인식 필터용 (§5-2)."""
    ix0, iy0 = max(item["x0"], region["x0"]), max(item["y0"], region["y0"])
    ix1, iy1 = min(item["x1"], region["x1"]), min(item["y1"], region["y1"])
    inter = max(0.0, ix1 - ix0) * max(0.0, iy1 - iy0)
    a = area(item)
    return inter / a if a > 0 else 0.0


def center_in(b, outer):
    cx, cy = (b["x0"] + b["x1"]) / 2, (b["y0"] + b["y1"]) / 2
    return outer["x0"] <= cx <= outer["x1"] and outer["y0"] <= cy <= outer["y1"]


def postprocess(scene):
    """§5의 후처리. 버린 항목과 이유를 함께 돌려준다."""
    kept, dropped = [], []
    ids = {i["id"] for i in scene["items"]}
    clusters = {i["id"] for i in scene["items"] if i["kind"] == "cluster"}

    for it in scene["items"]:
        b = it["bbox"]
        if not (b["x0"] < b["x1"] and b["y0"] < b["y1"]):
            dropped.append((it, "bbox 뒤집힘")); continue
        if any(overlap_ratio(b, r["bbox"]) >= 0.70 for r in scene["screen_regions"]):
            dropped.append((it, "화면 영역")); continue
        if it["support"] == "unknown" and not center_in(b, scene["surface"]["bbox"]):
            dropped.append((it, "상판 밖")); continue

        # 관계 정합성: 위반해도 버리지 않고 최상위로 떨어뜨린다
        p = it["member_of"]
        if p is not None and (p not in ids or p not in clusters
                              or p == it["id"] or it["kind"] == "cluster"):
            it = dict(it, member_of=None)
        kept.append(it)
    return kept, dropped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("photos", nargs="+")
    ap.add_argument("--out", default="runs/latest")
    args = ap.parse_args()

    import anthropic
    client = anthropic.Anthropic()
    schema, prompt = load_contract()
    out = pathlib.Path(args.out); out.mkdir(parents=True, exist_ok=True)
    lines = []

    for path in args.photos:
        name = pathlib.Path(path).stem
        print("파싱:", path)
        scene, usage = call(client, schema, prompt, load_image(path))
        (out / f"{name}.raw.json").write_text(
            json.dumps(scene, ensure_ascii=False, indent=2), encoding="utf-8")

        kept, dropped = postprocess(scene)
        unknown = sum(1 for i in kept if i["category"] == "unknown")
        needs_input = sum(1 for i in kept if i["label_confidence"] < 0.40)
        silhouette = sum(1 for i in kept if i["crop_quality"] < 0.45
                         or i["occlusion"] > 0.60)

        # 정답 대조용. hit 열을 사람이 채운다: o=맞음 x=허위 n=이름틀림
        rows = ["hit,id,kind,label,confidence,category,zone,support,crop_quality,features"]
        for i in kept:
            rows.append(",".join(['', i["id"], i["kind"],
                                  '"%s"' % i["label"].replace('"', "'"),
                                  f'{i["label_confidence"]:.2f}', i["category"],
                                  i["zone"], i["support"],
                                  f'{i["crop_quality"]:.2f}',
                                  '"%s"' % i["distinguishing_features"].replace('"', "'")]))
        (out / f"{name}.items.csv").write_text("\n".join(rows) + "\n", encoding="utf-8")

        lines += [
            f"[{name}]",
            f"  각도 {scene['capture_quality']['angle']}"
            f"  상판비율 {scene['capture_quality']['surface_ratio']:.2f}"
            f"  이슈 {scene['capture_quality']['issues']}",
            f"  화면영역 {len(scene['screen_regions'])}"
            f"  파싱불가영역 {len(scene['unparsed_regions'])}",
            f"  항목 {len(scene['items'])} → 유지 {len(kept)} / 버림 {len(dropped)}",
            *[f"    버림: {i['label']} ({why})" for i, why in dropped],
            f"  unknown {unknown} ({unknown / max(1, len(kept)):.0%})"
            f"  needs_input {needs_input}  실루엣행 {silhouette}",
            f"  토큰 in {usage.input_tokens} out {usage.output_tokens}",
            "",
        ]

    (out / "summary.txt").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
    print("정답 대조: *.items.csv의 hit 열을 채운 뒤 지표를 계산한다 "
          "(o=맞음, x=허위, n=이름틀림)")


if __name__ == "__main__":
    main()
