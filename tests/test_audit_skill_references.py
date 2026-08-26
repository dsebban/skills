from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / "scripts" / "audit_skill_references.py"


def write_skill(root: Path, name: str, body: str = "") -> Path:
    directory = root / name
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "SKILL.md").write_text(
        f"---\nname: {name}\ndescription: Test skill.\n---\n\n{body}",
        encoding="utf-8",
    )
    return directory


class AuditSkillReferencesTest(unittest.TestCase):
    def run_audit(self, repo: Path, *installed_roots: Path) -> subprocess.CompletedProcess[str]:
        command = [sys.executable, str(SCRIPT), "--repo", str(repo)]
        for root in installed_roots:
            command.extend(["--installed-root", str(root)])
        return subprocess.run(command, capture_output=True, text=True, check=False)

    def test_reports_all_current_failure_shapes_in_order(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            agents = Path(temp) / "agents"
            repo.mkdir()
            agents.mkdir()
            (repo / "README.md").write_text(
                "`skill://poteto-mode/...`\n```text\nskill://playbooks/...\n```\n",
                encoding="utf-8",
            )
            poteto = write_skill(
                repo / "skills",
                "poteto-mode",
                "Agent prose follows **writing-for-agents**.\n",
            )
            (poteto / "playbooks").mkdir()
            (poteto / "playbooks" / "authoring-a-skill.md").write_text(
                "Use **writing-for-agents** guidance.\n",
                encoding="utf-8",
            )
            (poteto / "references").mkdir()
            (poteto / "references" / "plan.md").write_text(
                "Use installed **writing-for-agents** guidance.\n",
                encoding="utf-8",
            )

            result = self.run_audit(repo, agents)

            self.assertEqual(result.returncode, 1)
            lines = result.stdout.splitlines()
            self.assertEqual(
                [line.split(": ")[-1] for line in lines[:-1]],
                [
                    "skill://poteto-mode/...",
                    "skill://playbooks/...",
                    "writing-for-agents",
                    "writing-for-agents",
                    "writing-for-agents",
                ],
            )
            self.assertEqual(lines[-1], "FAIL: 5 unresolved skill references")

    def test_accepts_local_external_nested_and_principle_references(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            agents = Path(temp) / "agents"
            repo.mkdir()
            agents.mkdir()
            poteto = write_skill(repo / "skills", "poteto-mode")
            (poteto / "playbooks").mkdir()
            (poteto / "playbooks" / "babysit.md").write_text("# Babysit\n", encoding="utf-8")
            write_skill(
                repo / "skills",
                "writing-for-agents",
                "Read `skill://technical-writing` and `skill://unslop`.\n",
            )
            for name in ("technical-writing", "unslop", "principle-build-the-lever"):
                write_skill(agents, name)
            (repo / "README.md").write_text(
                "\n".join(
                    [
                        "`skill://poteto-mode`",
                        "`skill://poteto-mode/playbooks/babysit.md`",
                        "Use **writing-for-agents**.",
                        "Apply the **build-the-lever** principle skill.",
                    ]
                ),
                encoding="utf-8",
            )

            result = self.run_audit(repo, agents)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stdout, "PASS: all skill references resolve\n")

    def test_principle_shorthand_requires_prefixed_skill(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            agents = Path(temp) / "agents"
            repo.mkdir()
            agents.mkdir()
            write_skill(agents, "build-the-lever")
            (repo / "README.md").write_text(
                "Apply the **build-the-lever** principle skill.\n",
                encoding="utf-8",
            )

            result = self.run_audit(repo, agents)

            self.assertEqual(result.returncode, 1)
            self.assertIn("SKILL_NOT_FOUND", result.stdout)

    def test_repository_skill_owns_nested_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            agents = Path(temp) / "agents"
            repo.mkdir()
            agents.mkdir()
            write_skill(repo / "skills", "poteto-mode")
            installed = write_skill(agents, "poteto-mode")
            (installed / "missing.md").write_text("stale\n", encoding="utf-8")
            (repo / "README.md").write_text("`skill://poteto-mode/missing.md`\n", encoding="utf-8")

            result = self.run_audit(repo, agents)

            self.assertEqual(result.returncode, 1)
            self.assertIn("URI_PATH_NOT_FOUND", result.stdout)

    def test_rejects_ambiguous_installed_nested_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            first = Path(temp) / "first"
            second = Path(temp) / "second"
            repo.mkdir()
            first.mkdir()
            second.mkdir()
            write_skill(first, "external")
            stale = write_skill(second, "external")
            (stale / "rule.md").write_text("stale\n", encoding="utf-8")
            (repo / "README.md").write_text("`skill://external/rule.md`\n", encoding="utf-8")

            result = self.run_audit(repo, first, second)

            self.assertEqual(result.returncode, 1)
            self.assertIn("SKILL_AMBIGUOUS", result.stdout)

    def test_rejects_case_mismatch_and_parent_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            agents = Path(temp) / "agents"
            repo.mkdir()
            agents.mkdir()
            write_skill(repo / "skills", "poteto-mode")
            poteto = repo / "skills" / "poteto-mode"
            (poteto / "Rule.md").write_text("exact case\n", encoding="utf-8")
            (repo / "README.md").write_text(
                "skill://\nskill://Poteto-mode\nskill://poteto-mode/../secret.md\nskill://poteto-mode/rule.md\n",
                encoding="utf-8",
            )

            result = self.run_audit(repo, agents)

            self.assertEqual(result.returncode, 1)
            self.assertIn("SKILL_NOT_FOUND", result.stdout)
            self.assertIn("URI_PATH_INVALID", result.stdout)
            self.assertIn("URI_INVALID", result.stdout)
            self.assertIn("URI_PATH_NOT_FOUND", result.stdout)


if __name__ == "__main__":
    unittest.main()
