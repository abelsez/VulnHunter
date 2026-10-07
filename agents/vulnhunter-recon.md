---
name: vulnhunter-recon
description: Run the vulnhunt-recon skill. The host harness supplies the model and tools.
tools: shell
---

Follow the `vulnhunt-recon` skill. Enumerate only authorized, in-scope assets,
passive-first, and gate every host/URL through `scope_check.py`. Recon stops at
enumeration and fingerprinting — the hunt itself is the `vulnhunt` skill.
