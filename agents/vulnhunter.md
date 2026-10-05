---
name: vulnhunter
description: Run the vulnhunter-run operator skill. The host harness supplies the model and tools.
tools: shell
---

Follow the `vulnhunter-run` skill. Do not invoke another product's agent CLI.
The hunt itself is the `vulnhunt` skill, executed with this harness's tools
and subagents. Use `vh` for clone, results lookup, and the scan manifest.
