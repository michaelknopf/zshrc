#!/usr/bin/env python3
"""Tests for bin/keyfile. Run: python3 bin/internal/test_keyfile.py

Stdlib unittest so this runs with the same bare `python3` the script itself uses.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

KEYFILE = Path(__file__).resolve().parent.parent / 'keyfile'


class KeyfileTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = Path(self.tmp.name) / 'keys.env'

    def write(self, text: str, mode: int = 0o600) -> None:
        self.store.write_text(text)
        self.store.chmod(mode)

    def run_kf(self, *args: str, **env: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(KEYFILE), *args],
            capture_output=True,
            text=True,
            env=os.environ | {'KEYFILE_PATH': str(self.store)} | env,
        )

    # --- parsing -----------------------------------------------------------

    def test_get_returns_value(self) -> None:
        self.write('# [g]\nKEY=value\n')
        self.assertEqual(self.run_kf('get', 'KEY').stdout, 'value\n')

    def test_strips_export_prefix_and_quotes(self) -> None:
        self.write('# [g]\nexport A=plain\nB="dq"\nC=\'sq\'\n')
        for key, want in (('A', 'plain'), ('B', 'dq'), ('C', 'sq')):
            self.assertEqual(self.run_kf('get', key).stdout, f'{want}\n')

    def test_keys_above_first_header_are_default_group(self) -> None:
        self.write('LOOSE=1\n\n# [g]\nGROUPED=2\n')
        self.assertEqual(self.run_kf('groups').stdout, 'default\ng\n')

    def test_comments_and_blank_lines_ignored(self) -> None:
        self.write('# [g]\n\n# a comment\nKEY=v\n   \n')
        self.assertEqual(self.run_kf('list', 'g').stdout, 'KEY\n')

    def test_value_containing_equals_and_hash(self) -> None:
        self.write('# [g]\nURL=a=b=c#frag\n')
        self.assertEqual(self.run_kf('get', 'URL').stdout, 'a=b=c#frag\n')

    # --- grouping ----------------------------------------------------------

    def test_run_exposes_only_requested_group(self) -> None:
        self.write('# [a]\nAKEY=1\n\n# [b]\nBKEY=2\n')
        got = self.run_kf('run', 'a', '--', 'printenv', 'BKEY')
        self.assertEqual(got.returncode, 1, 'BKEY must not leak into group a')
        self.assertEqual(self.run_kf('run', 'a', '--', 'printenv', 'AKEY').stdout, '1\n')

    def test_unknown_group_is_an_error(self) -> None:
        self.write('# [a]\nK=1\n')
        got = self.run_kf('env', 'nope')
        self.assertEqual(got.returncode, 1)
        self.assertIn('no such group', got.stderr)

    def test_list_without_group_shows_group_column(self) -> None:
        self.write('# [a]\nK=1\n')
        self.assertIn('a', self.run_kf('list').stdout)

    # --- quoting / injection ------------------------------------------------

    def test_env_output_is_eval_safe(self) -> None:
        self.write(
            '# [g]\n'
            'SPACES=hello world\n'
            "SQUOTE=it's\n"
            'DOLLAR=$(echo pwned)\n'
            'BACKTICK=`echo pwned`\n'
        )
        exports = self.run_kf('env', 'g').stdout
        probe = subprocess.run(
            ['bash', '-c', f'{exports}\nprintf "%s|%s|%s|%s" '
             '"$SPACES" "$SQUOTE" "$DOLLAR" "$BACKTICK"'],
            capture_output=True, text=True,
        )
        self.assertEqual(probe.stdout, "hello world|it's|$(echo pwned)|`echo pwned`")

    def test_run_passes_values_verbatim(self) -> None:
        self.write('# [g]\nV=$(echo pwned)\n')
        self.assertEqual(self.run_kf('run', 'g', '--', 'printenv', 'V').stdout,
                         '$(echo pwned)\n')

    # --- conflicts ----------------------------------------------------------

    def test_conflicting_values_refused(self) -> None:
        self.write('# [a]\nSHARED=one\n\n# [b]\nSHARED=two\n')
        for args in (('get', 'SHARED'), ('env', 'a'), ('groups',), ('list',)):
            got = self.run_kf(*args)
            self.assertEqual(got.returncode, 1, f'{args} should refuse')
            self.assertIn('defined twice', got.stderr)

    def test_same_value_under_two_names_is_allowed(self) -> None:
        self.write('# [g]\nA=tok\nB=tok\n')
        self.assertEqual(self.run_kf('list', 'g').returncode, 0)

    # --- permissions / missing store ---------------------------------------

    def test_loose_permissions_refused(self) -> None:
        self.write('# [g]\nK=v\n', mode=0o644)
        got = self.run_kf('list')
        self.assertEqual(got.returncode, 1)
        self.assertIn('expected 600', got.stderr)

    def test_missing_store_refused(self) -> None:
        got = self.run_kf('list')
        self.assertEqual(got.returncode, 1)
        self.assertIn('no key store', got.stderr)

    # --- run semantics ------------------------------------------------------

    def test_run_propagates_exit_code(self) -> None:
        self.write('# [g]\nK=v\n')
        self.assertEqual(self.run_kf('run', 'g', '--', 'sh', '-c', 'exit 42').returncode, 42)

    def test_run_forwards_double_dash_in_child_args(self) -> None:
        self.write('# [g]\nK=v\n')
        got = self.run_kf('run', 'g', '--', 'echo', '--', 'x')
        self.assertEqual(got.stdout, '-- x\n')

    def test_run_without_separator_is_an_error(self) -> None:
        self.write('# [g]\nK=v\n')
        got = self.run_kf('run', 'g', 'printenv')
        self.assertEqual(got.returncode, 1)
        self.assertIn('usage', got.stderr)

    def test_run_missing_command_reports_127(self) -> None:
        self.write('# [g]\nK=v\n')
        self.assertEqual(self.run_kf('run', 'g', '--', 'no_such_cmd_xyz').returncode, 127)

    def test_run_inherits_ambient_environment(self) -> None:
        self.write('# [g]\nK=v\n')
        got = self.run_kf('run', 'g', '--', 'printenv', 'AMBIENT', AMBIENT='present')
        self.assertEqual(got.stdout, 'present\n')

    # --- init / edit --------------------------------------------------------

    def test_init_creates_locked_down_store(self) -> None:
        nested = Path(self.tmp.name) / 'a' / 'b' / 'keys.env'
        got = self.run_kf('init', KEYFILE_PATH=str(nested))
        self.assertEqual(got.returncode, 0)
        self.assertEqual(nested.stat().st_mode & 0o777, 0o600)
        self.assertEqual(nested.parent.stat().st_mode & 0o777, 0o700)

    def test_init_does_not_clobber(self) -> None:
        self.write('# [g]\nPRECIOUS=keep\n')
        self.run_kf('init')
        self.assertIn('PRECIOUS', self.store.read_text())

    def test_edit_restores_permissions(self) -> None:
        self.write('# [g]\nK=v\n')
        sloppy = Path(self.tmp.name) / 'sloppy'
        sloppy.write_text('#!/bin/sh\nchmod 644 "$1"\n')
        sloppy.chmod(0o755)
        self.run_kf('edit', EDITOR=str(sloppy))
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o600)

    def test_edit_restores_permissions_after_rename_save(self) -> None:
        """The mechanism the chmod exists for: a new inode carrying umask perms."""
        self.write('# [g]\nK=v\n')
        renamer = Path(self.tmp.name) / 'renamer'
        renamer.write_text('#!/bin/sh\ncat "$1" > "$1.new"\nmv "$1.new" "$1"\n')
        renamer.chmod(0o755)
        self.run_kf('edit', EDITOR=str(renamer))
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o600)

    def test_edit_opens_a_store_that_fails_validation(self) -> None:
        self.write('# [a]\nS=one\n\n# [b]\nS=two\n', mode=0o644)
        marker = Path(self.tmp.name) / 'marker'
        editor = Path(self.tmp.name) / 'fixer'
        editor.write_text(f'#!/bin/sh\ntouch {marker}\nprintf "# [a]\\nS=one\\n" > "$1"\n')
        editor.chmod(0o755)
        self.run_kf('edit', EDITOR=str(editor))
        self.assertTrue(marker.exists(), 'edit must open a store needing repair')
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o600)

    def test_edit_reports_cleanly_when_store_is_gone(self) -> None:
        self.write('# [g]\nK=v\n')
        deleter = Path(self.tmp.name) / 'deleter'
        deleter.write_text('#!/bin/sh\nrm -f "$1"\n')
        deleter.chmod(0o755)
        got = self.run_kf('edit', EDITOR=str(deleter))
        self.assertEqual(got.returncode, 1)
        self.assertNotIn('Traceback', got.stderr)

    def test_edit_without_a_store_is_an_error(self) -> None:
        got = self.run_kf('edit', EDITOR='true')
        self.assertEqual(got.returncode, 1)
        self.assertIn('no key store', got.stderr)

    # --- misc ---------------------------------------------------------------

    def test_list_never_prints_values(self) -> None:
        self.write('# [g]\nSECRET=topsecretvalue\n')
        self.assertNotIn('topsecretvalue', self.run_kf('list').stdout)

    def test_unknown_key_is_an_error(self) -> None:
        self.write('# [g]\nK=v\n')
        self.assertEqual(self.run_kf('get', 'MISSING').returncode, 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
