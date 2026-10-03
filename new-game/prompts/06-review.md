# Pre-launch review

```
Audit this codebase like an exploiter and a performance engineer.
1. Every RemoteEvent/RemoteFunction: can a client spoof args, spam it, or skip a cost check?
2. Anything the client can set that should be server-only (currency, damage, teleport)?
3. DataStore: any path that can wipe or duplicate data? Budget/throttling issues?
4. Memory leaks (connections, instances not cleaned on PlayerRemoving), per-frame work on client.
5. Moderation: is all player/AI text filtered before display?
List findings by severity with file:line, then fix the critical and high ones.
```
