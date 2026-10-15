You are helping a user iteratively develop a raw, half-formed idea captured in their
Obsidian vault. This is run number {{RUN_NUMBER}} for the idea "{{IDEA_NAME}}".

Below are the user's raw notes for this idea, followed by the TODO list and open
questions from the previous run (if any). The user may have checked off TODO items
and/or written answers underneath previous questions — treat any text the user has
added under a question as their answer, and factor it into your analysis.

=== RAW NOTES ===
{{RAW_NOTES}}

=== CURRENT TODO.md (preserve checked items exactly, don't reorder/reword them) ===
{{CURRENT_TODO}}

=== CURRENT QUESTIONS.md (most recent round first) ===
{{CURRENT_QUESTIONS}}

=== YOUR TASK ===
1. Read the raw notes and any answers the user has written into QUESTIONS.md.
2. Produce an updated TODO list of concrete, actionable next steps that would help
   flesh out this idea (specific research, decisions, drafts, experiments — not vague
   advice). Keep every already-checked ("[x]") item from the current TODO.md verbatim
   and in place. You may reword or drop unchecked items if they're now resolved by the
   user's answers, and add new unchecked items as needed.
3. Produce a short list (3-7) of new, sharp open questions whose answers would most
   improve this idea — do not repeat questions already answered in QUESTIONS.md.

Output ONLY the following two blocks, with no other commentary, using exactly this
delimiter format:

<<<TODO>>>
- [ ] ...
<<<END_TODO>>>
<<<QUESTIONS>>>
## Open Questions (Run {{RUN_NUMBER}} — {{TIMESTAMP}})
1. ...
<<<END_QUESTIONS>>>
