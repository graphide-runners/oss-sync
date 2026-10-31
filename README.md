# oss-sync

Graphide shadows public repositories on graphide-ci from forks in the `graphide-oss`
organization (Ben, 2026-10-30). This repository lives in `graphide-runners` so its job never
queues behind the forks' jobs for graphide-oss's 20 hosted runners. Each fork's default branch follows its upstream one first-parent commit at
a time, so the fork's own CI runs once at each of upstream's commits, and graphide-ci's
shadow replays every job of those runs on our runners and compares them. Nothing is written
to any upstream repository.

- `repos.tsv`: the upstream, the fork and the branch.
- `sync.sh UPSTREAM FORK BRANCH`: one step. It waits while a push run of the fork is still
  going, steps to the next upstream commit (skipping ahead when more than 6 behind), picks
  the fork's own commits (its graphide setup pull request, once moved) onto it, and
  force-pushes with a lease.
- `.github/workflows/sync.yml`: `sync.sh` for every fork, every 15 minutes, with each fork's
  write deploy key from the secret `DEPLOY_KEY_<NAME>`. `workflow_dispatch` with `dry_run`
  prints the steps and pushes nothing.
- `setup.sh`: makes the forks once (Actions on, fork workflows on, approval required for
  outside contributors' pull requests, deploy keys, priming 3 commits behind).

- `fork-commits/<name>.sh`: the fork's own commits beyond its setup pull request, as scripts run
  in its checkout, so a commit that stops picking cleanly is made again: tokio's Loom jobs run in
  the fork (they are guarded on tokio-rs owning the repository), and rust-analyzer's CI runs on
  pushes to master (upstream runs it on pull requests and the merge queue only).

To add a repository: a line in `repos.tsv`, its secret name in `sync.yml`, then `setup.sh`.
