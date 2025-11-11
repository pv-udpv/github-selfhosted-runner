# Context/State Manager Integration Cookbook

## Purpose
Provides typical usage recipes, structural guides, and variable matrix for integrating context_manager API in GitHub Actions and runner workflows.

### Table of Contents
1. Context Layers and Matrix
2. Bash API Functions
3. Usage Patterns in Workflow YAML
4. State Checkpoint & Rollback
5. Best Practices

---

## 1. Context Layers
| Layer      | Example Var         | Provider        | Namespace         | Visibility      | Persistence      | Описание                        |
|------------|---------------------|-----------------|--------------------|-----------------|------------------|----------------------------------|
| App        | GITHUB_APP_ID       | User/App        | GITHUB_APP_*       | Secret/Public   | Permanent        | Аутентификация                  |
| Аккаунт    | github.actor        | GitHub/user     | GITHUB_USER_*      | Public          | Permanent        | CI инициатор, audit              |
| Repo       | github.repository   | GitHub/api      | GITHUB_REPO_*      | Public          | Permanent        | Scope workflow, runners          |
| Commit     | github.sha          | VCS             | COMMIT_*           | Public          | Per run          | Versioning, trace                |
| Workflow   | github.run_id       | Actions Runtime | WORKFLOW_*         | Internal        | Workflow run     | ID оркестрации                   |
| Job        | job.status          | Actions Runtime | JOB_*              | Internal        | Run              | Pause/rollback, status           |
| Runner     | runner.name         | Actions Runtime | RUNNER_*           | Internal        | Session          | Capacity, dynamic                |
| Workspace  | github.workspace    | Actions Runtime | WORKSPACE_*        | Internal        | Run              | Файлы workflow/job               |

---

## 2. Bash API Summary
- `context_manager_get <layer> <var>`
- `context_manager_set <layer> <var> <value>`
- `context_manager_export <layer>`
- `context_manager_checkpoint <layer>`
- `context_manager_rollback <layer>`

---

## 3. Usage in Workflow YAML
```yaml
steps:
  - name: Snapshot context
    run: scripts/context_manager.sh export runner
  - name: Check busy
    run: |
      if [[ $(scripts/context_manager.sh get runner busy) == true ]]; then exit 42; fi
  - name: Set status
    run: scripts/context_manager.sh set runner busy true
  - name: Persist checkpoint
    run: scripts/context_manager.sh checkpoint runner
  - name: Rollback
    if: failure()
    run: scripts/context_manager.sh rollback runner
```

---

## 4. Checkpoint/Stateful Ops Pattern
- Before state mutation: `context_manager_checkpoint <layer>`
- On error: `context_manager_rollback <layer>`

---

## 5. Best Practices
- Namespace all env vars
- Log context at each stage
- Use checkpoint/rollback for reliable CI
- Prefer stateless snapshots for audit
- Document variable usage in README

---

Full reference and chart: see docs/context_manager.md and [chart:20].
