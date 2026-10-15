#!/usr/bin/env bash
# Fake `claude` executable for offline testing. Ignores its arguments and
# echoes a canned --output-format json response so the pipeline (hash ->
# prompt build -> invoke -> parse -> write -> state update) can be exercised
# end to end with zero API cost.
cat <<'JSON'
{"result":"<<<TODO>>>\n- [ ] Write a one-paragraph pitch for the idea\n- [ ] List three similar existing products and how this differs\n<<<END_TODO>>>\n<<<QUESTIONS>>>\n## Open Questions (Run 1 — stub)\n1. Who is the primary user?\n2. What's the smallest version that could ship in a week?\n<<<END_QUESTIONS>>>"}
JSON
