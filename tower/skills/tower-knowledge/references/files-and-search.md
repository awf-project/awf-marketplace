# Native files and search

Paths are workspace-relative. Optional arguments marked `?`.

| Tool (`tower_` prefix) | Arguments | Behavior |
|---|---|---|
| `find_file` | `query` | Matching `paths` |
| `list_dir` | `path`, `recursive?`, `max_depth?` | Sorted indexed `entries`; root = `""` or `"."` |
| `search_text` | `pattern` | Matches: path, line number, content |
| `read_file` | `path`, `with_version?` | Content; version only with `with_version:true` |
| `create_file` | `path`, `content`, `expected_version?` | Creates **or overwrites** |
| `create_directory` | `path` | Recursive creation |
| `delete_file` | `path` | Deletes file/index entry; no version guard |
| `edit_range` | `path`, `start_byte`, `end_byte`, `replacement`, `expected_version?` | Byte edit; per-file errors |
| `global_replace` | `target`, `replacement`, `expected_versions?` | Literal replacement in all indexed files |
| `reindex` | none | Rebuild files/search; returns `files_indexed` |

`list_dir` excludes ignored paths and empty directories. `max_depth` must be positive
with `recursive:true`. Unknown directory prefix → empty listing; tracked file → invalid argument.
Index visibility: [setup](setup.md). Write contracts: [safe edits](safe-edits.md).

Payloads may be JSON inside a text content block.
Errors: unknown tool `-32001`, missing resource `-32002`, invalid arguments `-32602`,
execution failure `-32603`.
