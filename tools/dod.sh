#!/usr/bin/env bash
# 작업 완료 확인(DoD)을 한 번에 돌린다 — AGENTS.md §2.
# 성공한 단계는 한 줄만, 실패한 단계는 출력 끝부분을 보여 준다(에이전트가 읽는 출력량을 줄이려는 것).
# 사용: bash tools/dod.sh   (저장소 어디서 실행해도 된다)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONIOENCODING=utf-8
# Windows의 python3는 스토어 설치 안내 스텁일 수 있다 → 실제로 실행되는 것을 고른다.
PY=python3; "$PY" -c "" 2>/dev/null || PY=python
fail=0

step() {
  local name=$1; shift
  local out code
  out=$("$@" 2>&1); code=$?
  if [ $code -eq 0 ]; then
    echo "✓ $name"
  else
    echo "✗ $name (exit $code)"
    echo "$out" | tail -n 120
    fail=1
  fi
}

cd "$ROOT"
step "Python 문법 (tools/*.py)" "$PY" -c "import pathlib,sys; [compile(p.read_text(encoding='utf-8'), str(p), 'exec') for p in pathlib.Path('tools').glob('*.py')]"
step "문서 lint" "$PY" tools/docs_lint.py
step "채점기 실행 (runs/2026-09-02)" "$PY" tools/score.py runs/2026-09-02/*.items.csv

if command -v swift >/dev/null 2>&1; then
  cd "$ROOT/ios/DeskDexKit"
  step "swift test (DeskDexKit)" swift test
else
  echo "- swift test 건너뜀: Swift 툴체인 없음. push 후 CI의 ios 잡(macOS)으로 확인"
fi

exit $fail
