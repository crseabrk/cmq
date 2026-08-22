# Contributing to CMQ

Thanks for helping improve CMQ.

Before proposing a large feature, please open an issue describing the workflow it solves. CMQ intentionally stays focused on two-pane copy and move operations.

For code changes:

1. Fork the repository and create a focused branch.
2. Build with `./build.sh`.
3. Test navigation, copy, move, rename, Trash, and progress reporting with disposable files.
4. Open a pull request explaining the user-visible behavior and how you tested it.

Do not test destructive operations on valuable files.
