# Edit contracts

For existing files, `tower_read_file` with `with_version:true` returns content and
`version` (SHA-256 of raw bytes). Pass it as `expected_version` to `tower_edit_range`
or `tower_create_file`. Symbol-only reads do not supply whole-file versions.
Missing/null guards make native writes unconditional; `create_file` can overwrite.

Ranges are UTF-8 byte offsets `[start_byte,end_byte)`, with character-boundary endpoints:
equal offsets insert; empty replacement deletes. No implicit formatting.
Compute offsets from the versioned content. CAS conflict → reread and recompute;
never drop the guard or reuse stale offsets.

`tower_global_replace` affects all indexed occurrences, including comments/strings/prose.
`expected_versions` guards only listed paths; it **does not limit scope**. Search occurrences
first; use LSP rename for references or targeted edits for selective replacements.

AST/LSP edits use host `workspace/applyEdits`. Preview with `dry_run:true`; applying
recomputes against current content, so preview reserves nothing. Each mutating semantic
span needs a matching `base_hash`; overlapping spans reject that file's batch.
Inspect `per_file`, skipped edits, and `cas_conflict`; resolve/preview again after conflict.
Writes are atomic **per file**, with no cross-file rollback; global replacement can also
partially succeed. Tool-specific contracts: [semantic tools](semantic-tools.md).
