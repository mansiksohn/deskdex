#!/usr/bin/env python3
"""각 물건의 bbox 크롭 이미지 및 전체 bbox 시각화 이미지를 생성한다.

  python3 tools/visualize_crops.py scratch/photos/desk1.jpg runs/0902_gemini
"""
import argparse, json, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageOps


def visualize(photo_path, run_dir):
    run_dir = pathlib.Path(run_dir)
    photo_path = pathlib.Path(photo_path)
    name = photo_path.stem

    raw_json_path = run_dir / f"{name}.raw.json"
    if not raw_json_path.exists():
        raise SystemExit(f"오류: {raw_json_path} 파일이 없습니다.")

    scene = json.loads(raw_json_path.read_text(encoding="utf-8"))
    orig_img = ImageOps.exif_transpose(Image.open(photo_path)).convert("RGB")
    W, H = orig_img.size

    # 1. 크롭 이미지 저장 디렉토리
    crop_dir = run_dir / "crops" / name
    crop_dir.mkdir(parents=True, exist_ok=True)

    # 2. 전체 어노테이션 이미지 생성
    annotated = orig_img.copy()
    draw = ImageDraw.Draw(annotated)

    # 폰트 로드 (기본 폰트 또는 시스템 폰트)
    try:
        font = ImageFont.truetype("malgun.ttf", size=max(14, int(H * 0.018)))
    except Exception:
        font = ImageFont.load_default()

    html_cards = []

    for it in scene["items"]:
        item_id = it["id"]
        label = it["label"]
        b = it["bbox"]

        # 0~1 정규화 좌표 -> 픽셀 좌표
        x0, y0 = int(b["x0"] * W), int(b["y0"] * H)
        x1, y1 = int(b["x1"] * W), int(b["y1"] * H)

        # 여유 패딩 5%
        pw, ph = int((x1 - x0) * 0.05), int((y1 - y0) * 0.05)
        cx0, cy0 = max(0, x0 - pw), max(0, y0 - ph)
        cx1, cy1 = min(W, x1 + pw), min(H, y1 + ph)

        # 개별 크롭 저장
        if cx1 > cx0 and cy1 > cy0:
            crop_img = orig_img.crop((cx0, cy0, cx1, cy1))
            safe_label = "".join(c for c in label if c.isalnum() or c in (" ", "_", "-")).strip()
            crop_filename = f"{item_id}_{safe_label}.jpg"
            crop_path = crop_dir / crop_filename
            crop_img.save(crop_path, quality=92)

            html_cards.append(f"""
            <div class="card">
                <div class="crop-box"><img src="crops/{name}/{crop_filename}" alt="{label}"></div>
                <div class="info">
                    <div class="id-badge">{item_id}</div>
                    <div class="title">{label}</div>
                    <div class="meta">신뢰도: {it.get('label_confidence', 0):.2f} | 카테고리: {it.get('category', '')}</div>
                    <div class="meta">특징: {it.get('distinguishing_features', '')}</div>
                    <div class="checklist">
                        <label><input type="checkbox"> 크롭 알아볼 수 있음 (crop=o)</label>
                    </div>
                </div>
            </div>""")

        # 어노테이션 박스 그리기
        color = "#10b981" if it.get("kind") != "cluster" else "#3b82f6"
        for offset in range(3):  # 두께 3px
            draw.rectangle([x0 - offset, y0 - offset, x1 + offset, y1 + offset], outline=color)

        tag = f"{item_id}: {label}"
        tb = draw.textbbox((x0, max(0, y0 - 24)), tag, font=font)
        draw.rectangle([tb[0] - 2, tb[1] - 2, tb[2] + 2, tb[3] + 2], fill=color)
        draw.text((x0, max(0, y0 - 24)), tag, fill="white", font=font)

    # 화면 영역(screen_regions)은 주황색 점선/박스로 표시
    for sr in scene.get("screen_regions", []):
        sb = sr["bbox"]
        sx0, sy0, sx1, sy1 = int(sb["x0"] * W), int(sb["y0"] * H), int(sb["x1"] * W), int(sb["y1"] * H)
        draw.rectangle([sx0, sy0, sx1, sy1], outline="#f59e0b", width=2)
        draw.text((sx0, max(0, sy0 - 20)), f"SCREEN ({sr['kind']})", fill="#f59e0b", font=font)

    annotated_path = run_dir / f"{name}.annotated.jpg"
    annotated.save(annotated_path, quality=90)

    # HTML 뷰어 페이지 생성
    html_content = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<title>{name} - BBox & 크롭 검증 뷰어</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; }}
  h1 {{ font-size: 22px; margin-bottom: 8px; }}
  p {{ color: #94a3b8; margin-bottom: 24px; }}
  .overview {{ margin-bottom: 32px; background: #1e293b; padding: 16px; border-radius: 12px; }}
  .overview img {{ max-width: 100%; height: auto; border-radius: 8px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }}
  .card {{ background: #1e293b; border: 1px solid #334155; border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; }}
  .crop-box {{ background: #090d16; display: flex; align-items: center; justify-content: center; height: 220px; padding: 12px; }}
  .crop-box img {{ max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 6px; }}
  .info {{ padding: 16px; flex: 1; display: flex; flex-direction: column; gap: 6px; }}
  .id-badge {{ display: inline-block; background: #334155; color: #38bdf8; font-size: 12px; font-weight: bold; padding: 2px 8px; border-radius: 4px; align-self: flex-start; }}
  .title {{ font-size: 16px; font-weight: 600; color: #f1f5f9; }}
  .meta {{ font-size: 13px; color: #94a3b8; }}
  .checklist {{ margin-top: auto; padding-top: 12px; border-top: 1px solid #334155; font-size: 14px; color: #10b981; }}
</style>
</head>
<body>
  <h1>🔍 {name} BBox 검증 뷰어</h1>
  <p>각 물건 카드를 보면서 "카드에 띄웠을 때 알아볼 수 있는지(crop=o/x)" 및 라벨 일치 여부(hit=o/n/x)를 판정하세요.</p>

  <div class="overview">
    <h2>전체 BBox 오버레이</h2>
    <img src="{name}.annotated.jpg" alt="전체 BBox">
  </div>

  <h2>개별 물건 크롭 목록 ({len(html_cards)}개)</h2>
  <div class="grid">
    {''.join(html_cards)}
  </div>
</body>
</html>"""

    html_path = run_dir / f"{name}.viewer.html"
    html_path.write_text(html_content, encoding="utf-8")

    print(f"[OK] BBox image: {annotated_path}")
    print(f"[OK] Crop directory: {crop_dir} ({len(html_cards)} items)")
    print(f"[OK] HTML viewer: {html_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("photo")
    ap.add_argument("run_dir", default="runs/0902_gemini")
    args = ap.parse_args()
    visualize(args.photo, args.run_dir)


if __name__ == "__main__":
    main()
