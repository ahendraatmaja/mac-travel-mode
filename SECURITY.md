# Security

Travel Mode runs one command as administrator, `pmset -a disablesleep 1` or `0`, through the
standard macOS password dialog. Everything else runs as you. The app makes one network request:
the optional daily update check to `api.github.com`.

## Reporting a problem

Please report security issues privately: on this repository's **Security** tab, choose
**Report a vulnerability**. Don't open a public issue for them. You'll get an answer within a week.

## Checking a download

Each release lists the SHA-256 of its disk image. Compare it with:

```bash
shasum -a 256 ~/Downloads/Travel-Mode-<version>.dmg
```
