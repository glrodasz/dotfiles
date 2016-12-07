# Install

## How to stop iTunes from launching when using Keyboard media keys
```bash
launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist
```
