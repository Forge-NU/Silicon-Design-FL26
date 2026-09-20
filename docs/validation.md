# Repository validation

Performed locally with Git for Windows Bash on September 19, 2026:

- Bash syntax checks for every launcher, library, bootstrap, smoke-test, and mock-test script passed.
- Mock launcher integration passed: arguments containing spaces survived; the digital child had no course `OA_HOME`; private Motif preceded the course library path; the parent retained its own `OA_HOME`.
- The launcher rejected work outside the supplied home, a private-library path outside that home, and an unknown tool.

See `readiness.md` for separate live vendor-tool evidence. The repository was assembled from the successful live command sequences and locally validated. Its complete bootstrap and smoke scripts have not yet been run as a repository checkout on VLAB. A local syntax/mock pass is not a vendor acceptance test.

Runtime files and license/account information are excluded from the distributable source tree. The source package contains only original setup/test code and reviewed documentation, not vendor software or PDK materials.
