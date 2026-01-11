# System-wide Claude Code Personalization

- **Never commit or push directly to `main`.** If you make changes with main checked out, run create a new branch before committing.
- **Do not leave deprecated code behind.** We don't need it for backwards compatibility or for future reference. Delete it and update consumers to use the updated implementation.
- When creating PRs, do NOT add a "Test plan" section.
- Never run write operations against AWS without explicit permission from me!

## Design & Style
- Prefer object-oriented patterns over module-level functions and global variables.
- Composition over inheritance.
- Don't create wrapper methods that add abstraction without providing value (e.g., simplifying the interface, adding logic, or improving clarity).
- Keep components small and focused on one topic and one level of abstraction. Decompose large components (files/classes/functions etc.) into standalone, self-sufficient components that work together.
- **Levels of abstraction:** Structure code in hierarchical layers where high-level functions orchestrate by calling lower-level functions, which may in turn call even lower-level functions. Each function should operate at a single level of abstraction - don't mix high-level orchestration with low-level implementation details in the same function. If a function needs to perform a low-level operation, delegate it to a helper method or collaborator class. This creates code that reads like a summary at the top level, where you can drill down into details as needed.
- Use strict types and generic types whenever possible. However, don't add redundant type annotations if the type checker / compiler can infer them.
- Do not "deconstruct" objects into local variables unless the full expression referencing the attr is long and/or repeated often. For example, just use `obj.attr` instead of creating `attr = obj.attr`, unless its necessary for readability or performance.

## Python

- Prefer pydantic models or dataclasses over dictionaries to represent static types. Meaning, write classes to model data if you know the structure up front.
- Always use the `type` keyword with union types.
- NEVER import and re-export in a package's `__init__.py` file. We want imports to come from the package where the code is originally defined.
- Never put code in `__init__.py` files, unless there is a very specific reason.
- Never use `__all__` unless there is a very specific reason. Allow modules to implicitly export everything.
- MULTILINE docstrings MUST ALWAYS have a blank line after the opening triple quotes and before the closing triple quotes, like this:
    ```python
    """
    This is a docstring
    with mutliple lines.
    """
    ```
- Never add comments to ignore errors from mypy or pyright.
- Never use `__all__` unless there is a very specific reason. Allow modules to implicitly export everything.
