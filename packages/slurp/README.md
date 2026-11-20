# Screenshot selector

I use pinned Slurp for both rectangle clicks and free dragging. The screenshot
helper passes visible windows on stdin and `-o` for displays, without `-r`
(which would prohibit dragging).

My small patch preserves a hovered click target until the pointer moves at least
four logical pixels along either axis. Once crossed, area mode stays active
until release, even if the pointer returns close to its starting point. It does
not change touch gestures or restricted/point modes.

`selection-test.c` includes Slurp's actual source handlers and runs during the
package build without a display, pointer injection, or compositor. The package
is also exposed as the `screenshot-selector` flake check. After a Slurp update,
rebase the patch and rerun the checks; no independent source version is pinned.
Only the screenshot helper's runtime uses this patched package.
