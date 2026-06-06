# Raising the GPU memory cap (24 GB Macs)

On Apple Silicon the GPU shares unified memory. The default Metal "wired" cap leaves roughly 16-18 GB usable for the GPU on a 24 GB Mac. Devstral Q4 (~15 GB) fits, but headroom for KV cache is thin. Raising the cap to **18 GB (75 % of 24)** helps. Do **not** exceed ~80 % or the OS can stall.

macstral never runs `sudo` for you. Run these yourself.

## Persist across reboots (LaunchDaemon)

1. Create the plist:

```bash
cat > /tmp/com.local.iogpu.wiredlimit.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.iogpu.wiredlimit</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/sbin/sysctl</string>
        <string>iogpu.wired_limit_mb=18432</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST
```

2. Install and load it (sudo):

```bash
sudo cp /tmp/com.local.iogpu.wiredlimit.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.local.iogpu.wiredlimit.plist
sudo chmod 644 /Library/LaunchDaemons/com.local.iogpu.wiredlimit.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.local.iogpu.wiredlimit.plist
```

3. Apply now without rebooting + verify:

```bash
sudo sysctl iogpu.wired_limit_mb=18432
sysctl iogpu.wired_limit_mb   # expect: iogpu.wired_limit_mb: 18432
```

## Undo

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.local.iogpu.wiredlimit.plist
sudo rm /Library/LaunchDaemons/com.local.iogpu.wiredlimit.plist
```

> With Q3_K_M (~11.5 GB) the cap bump is optional on 24 GB: the model fits with headroom. Apply it if you observe paging under heavy agentic context load. 32 GB+ Macs do not need this.
