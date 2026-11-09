# Instructions for AI Coding Agents (AGENTS.md)

Welcome, agent. You are collaborating on the **Modern Computer Architecture (MCA) Group Project (Project 7: 2-Way Set-Associative Cache with LRU)**.

To maintain engineering discipline, project integrity, authentic Git history, and seamless multi-member collaboration, you **must adhere strictly to the following standing workflow and operational rules for ALL prompts**.

---

## Standing Workflow for All Later Prompts

1. **Read Specifications First & Inspect Working Tree**:
   - Always read `PROJECT_BRIEF.md`, `docs/interface.md`, and `HANDOFF.md` first.
   - Inspect the latest commits (`git log -n 5`) and the working tree (`git status`).
   - Work strictly on the assigned **Phase I** handoff. Do not leapfrog, work on future members' tasks, or touch Phase II deliverables.

2. **Verify Branch, Identity, and Synchronize**:
   - Confirm the current repository and that you are on the `main` branch.
   - Fetch from `origin` (`git fetch origin`) and fast-forward to `origin/main` before beginning any edits.
   - If there are unrelated local changes, conflicting history, or a Git identity mismatch, preserve all existing work and stop to explain the exact blocker to the user.

3. **Authentic Git Identity & Meaningful Multi-Stage Commits**:
   - Use the current member's configured Git identity. Never change author identity on someone's behalf or commit under another member's name.
   - Make at least **three substantive commits** during the task, one per completed stage.
   - Stage named files explicitly (`git add <file>`), inspect the staged diff (`git diff --staged`), and run all relevant checks before each commit.
   - Prohibited: No empty commits, no invented results, no rewritten authorship, and no splitting a single atomic change merely to artificially inflate history.

4. **Honest Handoff Logging & Safe Push**:
   - Record actual commands executed, real tool outputs, verified passing assertion counts, known limitations, modified files, and the next handoff in `HANDOFF.md`.
   - Push directly with `git push origin main` at the end of the task.
   - **Never force-push (`git push --force`)**.
   - If `main` has advanced remotely, integrate cleanly, re-run all affected simulation checks, and retry. Stop immediately for any genuine conflict that cannot be resolved safely.

5. **Verification of Remote State & Comprehensive Reporting**:
   - Verify the push by comparing local `HEAD` (`git rev-parse HEAD`) to the remote hash returned by `git ls-remote origin refs/heads/main`.
   - Report the commit hashes, verification checks run, push status, and the immediate next action.
   - If authentication or branch protection blocks the push, report the exact blocker clearly and preserve all local commits.

---

## Phase I Team Work Order

Development strictly follows this sequential pipeline:
$$\text{Kushal (scaffold)} \longrightarrow \text{Krishna (storage/LRU)} \longrightarrow \text{Apoorva (controller)} \longrightarrow \text{Prachee (comparison)} \longrightarrow \text{Kushal (verification)} \longrightarrow \text{Vani (report/demo package)}$$

- **Krishna**: Focus exclusively on `rtl/cache_2way_store.v` and its localized unit tests.
- **Apoorva**: Focus exclusively on `rtl/cache_2way.v` (controller FSM and memory fill integration).
- **Prachee**: Focus exclusively on `rtl/cache_direct.v` (direct-mapped baseline).
- **Kushal (Round 2)**: Focus exclusively on `tb/` testbenches and comparative simulation scripts in `scripts/`.
- **Vani**: Focus exclusively on `report/` (IEEE paper), `demo/` (video materials), and `docs/evidence/`.

---

## Preserving Agreed Interfaces

The hardware contracts defined in `PROJECT_BRIEF.md` and `docs/interface.md` are frozen:
- Do not alter module names (`cache_2way`, `cache_direct`, `cache_2way_store`).
- Do not add, remove, rename, or resize any interface ports.
- Adhere strictly to the synchronous active-high reset (`rst`) and single outstanding request handshake protocol (`req_valid`, `req_ready`, `resp_valid`, `resp_hit`, `resp_data`).
- Maintain the specified bit slicing for tags, sets, words, and byte offsets.

---

## Rigorous Verification Standards

- Never claim a module or test works without actually running the toolchain.
- Use Icarus Verilog (`iverilog` / `vvp`) with `-g2012` for SystemVerilog testbenches or standard Verilog-2001 for RTL.
- Capture real command line output, check return codes, and observe actual waveform signals or terminal assertions.
- Never write tests that trivially assert `true` or bypass the RTL logic.
- Never commit private API keys, credentials, or personal contact details.
