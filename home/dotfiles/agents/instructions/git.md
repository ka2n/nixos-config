## Git

- `git commit` / `git push` may print `.../mise/installs/ruby/...: symbol lookup error: ... GLIBC_PRIVATE`
  from git hooks. This is harmless noise (mise ruby × nix glibc mismatch); the operation itself succeeds.
  Judge success by exit code / `git log`, never retry because of this message.

