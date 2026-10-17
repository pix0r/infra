# Reviewed stages, applied one at a time

These patches are **prepared diffs, not executed migrations**. Stage A is PR #28.
Apply B, C, then D in separate PRs, each only after the previous stage's real
apply and validation have completed. `git apply <patch>` from the repository root
materializes that stage. Rebase/review if main changes first. Never apply all
patches to main in one deployment.

- `A-readiness-plan.txt`: actual refreshed plan; only runner-local key-file creation.
- `B-adopt-standard.patch`: 50/standard defaults and separate protected normal
  storage. Clone a stopped snapshot and import its UUID **before merging**. A plan
  proposing blank-storage creation is not acceptable for this migration.
- `C-cutover.patch`: attach only the adopted replacement, expose active/legacy
  IDs. No Simple Backup in this update. The provider starts a stopped VM.
- `D-simple-backup.patch`: Week at 0900, only after cutover is completed/healthy
  and both attached disks have no individual rule.

Tests exercise the real stack's expressions with external providers mocked and
computed IDs overridden. They are plan-only and never bootstrap a server. A has
1 test, B has 2, C has 3, D has 4. Each new contract was observed failing before
its implementation. Mock tests do not establish provider API behavior or live
recovery. Real post-import/cutover/backup plans cannot be produced truthfully
until those predecessor states exist; generate and review them at their gates.

See [the runbook](../storage-migration.md) for exact inventory, cost, downtime,
shutdown/clone/import ordering, recovery proof, rollback and cleanup conditions.
