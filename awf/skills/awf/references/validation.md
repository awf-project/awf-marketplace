# Input Validation

## Input Definition

```yaml
inputs:
  - name: email
    type: string
    required: true
    validation:
      pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
```

## Supported Types

| Type | Example |
|------|---------|
| `string` | `"hello"` |
| `integer` | `42` |
| `boolean` | `true` |

## Validation Rules

### Pattern (regex)

```yaml
validation:
  pattern: "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
```

### Enum (allowed values)

```yaml
validation:
  enum: [dev, staging, prod]
```

### Min/Max (numeric range)

```yaml
validation:
  min: 1
  max: 100
```

### File Exists

```yaml
validation:
  file_exists: true
```

### File Extension

```yaml
validation:
  file_extension: [".yaml", ".yml", ".json"]
```

## Combining Rules

```yaml
inputs:
  - name: config
    type: string
    required: true
    validation:
      file_exists: true
      file_extension: [".yaml", ".yml"]
```

## Error Handling

Validation errors are collected (non-fail-fast):

```bash
awf run deploy --input email=invalid --input count=999
```

```
input validation failed: 2 errors:
  - inputs.email: does not match pattern
  - inputs.count: value 999 exceeds maximum 100
```

Returns exit code 1 (User Error).

## JSON Error Output

```bash
awf run deploy --input email=invalid -f json
```

```json
{
  "success": false,
  "error": {
    "code": 1,
    "type": "validation_error",
    "details": {
      "errors": [
        {"input": "email", "rule": "pattern", "message": "does not match pattern"}
      ]
    }
  }
}
```

## Complete Example

```yaml
name: deploy
version: "1.0.0"

inputs:
  - name: env
    type: string
    required: true
    validation:
      enum: [dev, staging, prod]
  - name: version
    type: string
    required: true
    validation:
      pattern: "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
  - name: config_file
    type: string
    required: true
    validation:
      file_exists: true
      file_extension: [".yaml", ".yml"]
  - name: replicas
    type: integer
    default: 2
    validation:
      min: 1
      max: 10
  - name: dry_run
    type: boolean
    default: false
```

## Best Practices

1. **Validate file inputs** - Use `file_exists`
2. **Use enums for fixed choices** - Prevents typos
3. **Set sensible defaults** - Reduce required inputs
4. **Combine rules** - Comprehensive validation
