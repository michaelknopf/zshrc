# System-wide Claude Code Personalization

## Python

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
