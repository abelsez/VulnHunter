# Phase 1 — Scope & Program Intake

**Goal:** record *who authorized this*, *what is in scope*, and *what is
excluded* — and normalize both into machine-readable scope files before any
tool runs.

## Steps

1. **Authorization record.** Write a short block to `${VULNHUNT_RECON_DIR}/01_scope.md`:

   - Target name and program/platform (e.g., HackerOne program name, engagement ID, or "own asset").
   - The authorization basis in one line (program policy URL, SOW reference, or "owner").
   - The date and the operator.

2. **Normalize scope.** Ensure `SCOPE_DIR/in_scope.txt` and
   `SCOPE_DIR/out_of_scope.txt` exist and are non-empty. Normalize every line:
   strip comments (`#`), trim whitespace, lowercase hosts, drop trailing dots,
   keep `*.` wildcards only on the leftmost label. Write the normalized copies
   to `${VULNHUNT_RECON_DIR}/in_scope.txt` and `${VULNHUNT_RECON_DIR}/out_of_scope.txt`.

   If `in_scope.txt` is empty or missing, **STOP**: report "no scope defined"
   and do not continue.

3. **Sanity-check scope.** Grep the normalized scope for anything that looks
   wrong: a bare IP with no CIDR, a wildcard with more than one label
   (`*.*.example.com`), or an out-of-scope entry duplicated in-scope. Flag
   conflicts; when in-scope and out-of-scope disagree, out-of-scope wins.

4. **Test the gate.** Run `scripts/scope_check.py` with an obviously in-scope
   host and an obviously out-of-scope host using the normalized files, to
   confirm the gate behaves before real data flows through it:

   ```bash
   python3 scripts/scope_check.py --in-scope "$VULNHUNT_RECON_DIR/in_scope.txt" \
       --out-of-scope "$VULNHUNT_RECON_DIR/out_of_scope.txt" \
       --explain example.com admin.example.com
   ```

5. **Record.** Write the normalized scope summary (counts + the two test
   results) to `01_scope.md`. Do not include secrets in the record.

## Output

- `01_scope.md` — authorization record + normalized scope summary
- `in_scope.txt`, `out_of_scope.txt` — normalized copies used by all later phases
