// Claude Code SessionStart hook (.claude/settings.json) — 세션을 시작할 때 "지금 어디서 작업하는지"를
// 컨텍스트에 넣는다. 오래된 브랜치에서 모르고 시작하는 것, 다른 브랜치·워크트리의 커밋이 main에
// 안 들어간 채 잊히는 것을 막는다(글불 프로젝트에서 실제로 겪은 문제).
// 네트워크(git fetch)는 쓰지 않는다 — 로컬에 있는 origin/main 기준이다. 실패해도 세션을 막지 않는다.
import { execFileSync } from "node:child_process";

const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const tryGit = (...args) => {
  try { return execFileSync("git", ["-C", cwd, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); }
  catch { return ""; }
};

const BASE = "origin/main";
const lines = ["[DeskDex 세션 브리핑]"];

const branch = tryGit("rev-parse", "--abbrev-ref", "HEAD");
const [behind, ahead] = (tryGit("rev-list", "--left-right", "--count", `${BASE}...HEAD`) || "0 0").split(/\s+/).map(Number);
const fetched = tryGit("log", "-1", "--format=%cr", BASE);
lines.push(`- 지금: ${branch} (${BASE}보다 ${behind}개 뒤, ${ahead}개 앞. ${BASE} 마지막 커밋 ${fetched || "알 수 없음"})`);
if (behind > 20) lines.push(`  ⚠️ ${BASE}보다 많이 뒤처져 있다. 작업 전에 최신 main 기준인지 확인할 것.`);
const dirty = tryGit("status", "--porcelain").split(/\r?\n/).filter(Boolean).length;
if (dirty) lines.push(`- 커밋 안 된 변경 ${dirty}개가 있다.`);

// 이 워크트리 밖의 로컬 브랜치 중 main에 안 들어간 커밋이 있는 것.
const pending = [];
for (const ref of tryGit("for-each-ref", "--format=%(refname:short)", "refs/heads").split(/\r?\n/).filter(Boolean)) {
  if (ref === branch || ref === "main") continue;
  const subjects = tryGit("log", "--format=%ad %s", "--date=short", `${BASE}..${ref}`).split(/\r?\n/).filter(Boolean);
  if (subjects.length) pending.push(`  - [${ref}] ${subjects.length}개: ${subjects.slice(0, 3).join(" / ")}`);
}
if (pending.length) lines.push("- main에 안 들어간 커밋이 있는 다른 로컬 브랜치(결정이 빠져 있을 수 있다):", ...pending);

lines.push("- 먼저 읽을 것: docs/CURRENT.md(현재 상태), AGENTS.md(규칙·함정). 사용자가 방향을 정하면 그 턴에 docs/DECISIONS.md에 항목을 남긴다.");
console.log(lines.join("\n"));
