## ISSUES

The official issue tracker for the slurm-gcp repo is at
https://bugs.schedmd.com/

## PATCH SUBMISSION

We welcome code contributions and patches, but **we do not accept Pull Requests
through Github at this time.** Please submit patches as attachments to new bugs
under the "C - Contributions" severity level.

Please break patches up into logically separate chunks, while ensuring that each
patch can still run without errors. (Anticipate that a developer using
`git bisect` may pick any intermediate commit at some point.)

If you decided to reformat a file, please submit non-functional changes
(spelling corrections, formatting discrepancies) in a separate patch. This makes
reviewing substantially easier, and allows us to focus our attention on the
functional differences.

If you make an automated change (changing a function name, fixing a pervasive
spelling mistake), please send the command/regex used to generate the changes
along with the patch, or note it in the commit message.

While not required, we encourage use of `git format-patch` to geneate the patch.
This ensures the relevant author line and commit message stay attached. Plain
`diff`'d output is also okay. In either case, please attach them to the bug for
us to review. Spelling corrections or documentation improvements can be
suggested without attaching the patch as long as you describe their location.

## CODING GUIDELINES

This repo attempts to follow the PEP 8 style guide for Python
(https://www.python.org/dev/peps/pep-0008/).
