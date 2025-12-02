# System-wide Claude Code Personalization

- Do not leave deprecated code behind. We don't need it for backwards compatibility, or for future reference. Delete it and update consumers to use the updated implementation.
- When creating PRs, do NOT add a "Test plan" section.

## Python

### Design
- Prefer object-oriented patterns over module-level functions and global variables.
- Prefer composition over inheritance.
- Use strict types and generic types whenever possible. However, don't add redundant type annotations if the type checker can infer them.
- Prefer pydantic models or dataclasses over dictionaries to represent static types. Meaning, write classes to model data if you know the structure up front.
- Always use the `type` keyword with union types.
- Do not "deconstruct" objects into local variables unless the full expression referencing the attr is long and/or repeated often. For example, just use `obj.attr` instead of creating `attr = obj.attr`.
- NEVER import and re-export in a package's `__init__.py` file. We want imports to come from the package where the code is originally defined.
- Never put code in `__init__.py` files, unless there is a very specific reason.


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
