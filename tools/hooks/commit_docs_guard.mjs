// Claude Code PreToolUse(Bash) hook (.claude/settings.json) — 코드만 바뀌고 문서는 그대로인 커밋을 막는다.
// 세션에서 정한 결정이 코드에만 남고 문서에 안 남는 문제를 커밋 시점에 잡는다. 기준은 넓게 잡았다 —
// 문서 변경이 정말 필요 없으면 커밋 메시지에 [docs-skip]을 넣으면 통과한다(예: 주석 오타, 리팩터).
import { execFileSync } from "node:child_process";

let input = "";
process.stdin.on("data", (d) => (input += d)).on("end", () => {
  let cmd = "";
  try { cmd = JSON.parse(input)?.tool_input?.command ?? ""; } catch { process.exit(0); }
  if (!/\bgit\b[^\n]*\bcommit\b/.test(cmd) || cmd.includes("[docs-skip]") || /--amend\b/.test(cmd)) process.exit(0);

  const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const git = (...a) => { try { return execFileSync("git", ["-C", cwd, ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }); } catch { return ""; } };
  const files = new Set(git("diff", "--cached", "--name-only").split(/\r?\n/).filter(Boolean));
  // 같은 명령 안에서 git add / commit -a를 하면 아직 스테이징 전이라 작업 트리 변경도 함께 본다.
  if (/\bgit\s+add\b|\bcommit\b[^\n]*\s-[a-zA-Z]*a/.test(cmd)) {
    for (const l of git("status", "--porcelain").split(/\r?\n/)) if (l.trim()) files.add(l.slice(3).replace(/^"|"$/g, "").split(" -> ").pop());
  }

  const isCode = (f) =>
    (/^ios\/(App|DeskDexKit\/Sources)\//.test(f) && /\.swift$/.test(f)) ||
    /^ios\/(project\.yml|DeskDexKit\/Package\.swift)$/.test(f) ||
    (/^tools\/[^/]+\.py$/.test(f) && f !== "tools/docs_lint.py");
  const isDoc = (f) => /^(docs\/(CURRENT|DECISIONS|design|scene-schema)\.md|AGENTS\.md)$/.test(f);
  const code = [...files].filter(isCode);
  if (code.length === 0 || [...files].some(isDoc)) process.exit(0);

  const reason =
    `코드가 바뀌었는데(${code.slice(0, 4).join(", ")}${code.length > 4 ? " 외" : ""}) docs/CURRENT.md·DECISIONS.md·design.md·scene-schema.md·AGENTS.md 중 바뀐 게 없다. ` +
    "바뀐 사실은 CURRENT.md에, 사용자가 정한 결정은 DECISIONS.md에 반영해 같은 커밋에 넣을 것. " +
    "정말 문서에 남길 게 없으면(주석·리팩터 등) 커밋 메시지에 [docs-skip]을 넣고 다시 커밋한다.";
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: reason },
  }));
});
