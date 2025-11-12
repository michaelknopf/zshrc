# System-wide Claude Code Personalization

- Do not leave deprecated code behind. We don't need it for backwards compatibility, or for future reference. Delete it and update consumers to use the updated implementation.

## Python

### Design
- Prefer object-oriented patterns over module-level functions and global variables.
- Prefer composition over inheritance.
- Use strict types and generic types whenever possible. However, don't add redundant type annotations if the type checker can infer them.


### Docstrings

MULTILINE docstrings MUST ALWAYS have a blank line after the opening triple quotes and before the closing triple quotes, like this:
```python
"""
This is a docstring
with mutliple lines.
"""
```

### Static Typing

Never add comments to ignore errors from mypy or pyright.

### __all__

Never use `__all__` unless there is a very specific reason. Allow modules to implicitly export everything.
