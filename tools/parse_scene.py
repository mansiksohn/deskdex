#!/usr/bin/env python3
"""장면 파싱 검증 러너. 백엔드: Gemini (google-genai SDK).

스키마와 프롬프트를 docs/scene-schema.md에서 직접 읽는다. 문서가 단일
출처이고, 스크립트가 문서와 어긋날 수 없다.

  pip install google-genai pillow
  export GEMINI_API_KEY=...
  python3 tools/parse_scene.py photos/*.jpg --out runs/2026-09-02

각 사진에 대해:
  <out>/<이름>.raw.json        VLM 원본 응답
  <out>/<이름>.items.csv       정답 대조용. hit 열을 손으로 채운다
  <out>/summary.txt            항목 수, unknown 비율, 후처리에서 버린 수

이 스크립트는 원래 Anthropic Claude API용으로 짰다. Claude 구독은 API 크레딧을
별도로 안 주고(콘솔에서 따로 결제 등록 필요), Gemini로 실측을 먼저 진행하기로
해서 호출부만 갈아끼웠다. google-genai 2.21.0을 실제로 설치해 API를 직접
확인하고 썼다 — 특히 `response_json_schema`(JSON Schema 그대로 받는 필드)가
`$ref`/`$defs`/`anyOf`/`additionalProperties`를 전부 지원해서, docs/scene-schema.md
의 스키마를 거의 그대로 넘길 수 있었다. `const`만 그 필드가 지원하는 키워드
목록에 없어서 `enum` 하나짜리로 바꾼다 (to_gemini_schema 참조). 그 밖의 실제
호출(이미지 인코딩, finish_reason 분기 등)은 이번이 첫 실행이라 미검증이다.
"""
import argparse, io, json, os, pathlib, re, sys

DOC = pathlib.Path(__file__).resolve().parent.parent / "docs" / "scene-schema.md"
DEFAULT_MODEL = "gemini-3.6-flash"  # 사용자가 이 모델로 실제 desk1 테스트에 성공했다


def load_contract():
    """문서에서 스키마(첫 json 블록)와 프롬프트(첫 text 블록)를 꺼낸다."""
    md = DOC.read_text(encoding="utf-8")
    schema = json.loads(re.search(r"```json\n(.*?)```", md, re.S).group(1))
    prompt = re.search(r"```text\n(.*?)```", md, re.S).group(1).strip()
    return schema, prompt


def to_gemini_schema(schema):
    """Gemini의 response_json_schema가 받아들이는 형태로 최소한만 고친다.

    실제 지원 키워드 목록(google-genai 2.21.0, GenerateContentConfig.response_json_schema
    docstring에서 확인): $id, $defs, $ref, $anchor, type, format, title,
    description, enum, items, prefixItems, minItems, maxItems, minimum, maximum,
    anyOf, oneOf, properties, additionalProperties, required, propertyOrdering.

    scene-schema.md의 스키마에서 이 목록에 없는 건 `const` 하나뿐이다
    (schema_version 필드). anyOf(§member_of의 nullable 표현)는 목록에 있어서
    안 건드린다.
    """
    def walk(node):
        if isinstance(node, dict):
            out = {}
            for k, v in node.items():
                if k == "const":
                    out["enum"] = [v]
                    out.setdefault("type", "string")
                else:
                    out[k] = walk(v)
            return out
        if isinstance(node, list):
            return [walk(v) for v in node]
        return node

    return walk(schema)


def load_image(path):
    """EXIF orientation을 픽셀에 적용한 뒤 JPEG 원본 바이트로 돌려준다.

    회전이 남아 있으면 좌표 규약과 zone이 통째로 틀어진다 (scene-schema.md §5).
    """
    from PIL import Image, ImageOps

    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    img.thumbnail((1568, 1568))  # 긴 변 기준. 이보다 크면 서버가 어차피 줄인다
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def call(client, model, gemini_schema, prompt, image_bytes):
    from google.genai import types

    resp = client.models.generate_content(
        model=model,
        contents=[
            types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
            "이 책상 사진을 분석하라.",
        ],
        config=types.GenerateContentConfig(
            system_instruction=prompt,
            response_mime_type="application/json",
            response_json_schema=gemini_schema,
            max_output_tokens=16000,
        ),
    )

    if resp.prompt_feedback and resp.prompt_feedback.block_reason:
        raise SystemExit("  입력이 막혔다: %s" % resp.prompt_feedback.block_reason)
    if not resp.candidates:
        raise SystemExit("  응답 후보가 없다 (원본: %r)" % resp)

    finish = resp.candidates[0].finish_reason
    if finish and finish.name == "MAX_TOKENS":
        sys.stderr.write("  경고: MAX_TOKENS에 닿았다. JSON이 잘렸을 수 있다\n")
    elif finish and finish.name not in ("STOP", "FINISH_REASON_UNSPECIFIED"):
        raise SystemExit("  생성 중단: %s" % finish.name)

    return json.loads(resp.text), resp.usage_metadata


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
        # display(모니터 자체)는 예외. 모니터의 bbox는 곧 자기 화면이라 겹침이
        # 항상 100%에 가깝다 — "화면 속 내용"이 아니라 "모니터라는 물건"이다.
        if it["category"] != "display" and any(
            overlap_ratio(b, r["bbox"]) >= 0.70 for r in scene["screen_regions"]
        ):
            dropped.append((it, "화면 영역")); continue
        if it["support"] == "off_desk":
            dropped.append((it, "책상 아님")); continue
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
    ap.add_argument("--model", default=DEFAULT_MODEL)
    args = ap.parse_args()

    from google import genai

    client = genai.Client()  # GEMINI_API_KEY 또는 GOOGLE_API_KEY 환경변수를 읽는다
    schema, prompt = load_contract()
    gemini_schema = to_gemini_schema(schema)
    out = pathlib.Path(args.out); out.mkdir(parents=True, exist_ok=True)
    lines = []

    for path in args.photos:
        name = pathlib.Path(path).stem
        print("파싱:", path)
        scene, usage = call(client, args.model, gemini_schema, prompt, load_image(path))
        (out / f"{name}.raw.json").write_text(
            json.dumps(scene, ensure_ascii=False, indent=2), encoding="utf-8")

        kept, dropped = postprocess(scene)
        unknown = sum(1 for i in kept if i["category"] == "unknown")
        needs_input = sum(1 for i in kept if i["label_confidence"] < 0.40)
        silhouette = sum(1 for i in kept if i["crop_quality"] < 0.45
                         or i["occlusion"] > 0.60)

        rows = [
            "# hit  : o=맞음(실재+이름OK) n=실재하나 이름틀림 x=허위(그런 물건 없다)",
            "#        모델이 통째로 놓친 물건은 맨 아래에 hit=miss로 행을 추가한다",
            "# crop : 이 물건 사진을 잘라서 카드에 띄웠을 때 알아볼 수 있나. o/x",
            "hit,crop,id,kind,label,confidence,category,zone,support,crop_quality,features",
        ]
        for i in kept:
            rows.append(",".join(['', '', i["id"], i["kind"],
                                  '"%s"' % i["label"].replace('"', "'"),
                                  f'{i["label_confidence"]:.2f}', i["category"],
                                  i["zone"], i["support"],
                                  f'{i["crop_quality"]:.2f}',
                                  '"%s"' % i["distinguishing_features"].replace('"', "'")]))
        rows.append("# 놓친 물건은 아래에 이렇게: miss,,,,\"나무 주걱\",,,,,,")
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
            f"  토큰 in {usage.prompt_token_count} out {usage.candidates_token_count}",
            "",
        ]

    (out / "summary.txt").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
    print("정답 대조: *.items.csv의 hit 열을 채운 뒤 지표를 계산한다 "
          "(o=맞음, x=허위, n=이름틀림)")


if __name__ == "__main__":
    main()
