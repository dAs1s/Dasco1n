# C:\Dasco1n\start-stream.ps1
# (Run this script elevated; it spawns 4 elevated PowerShells—one per service)

$ps = "powershell.exe"
$opt = "-NoLogo -NoProfile -ExecutionPolicy Bypass"

# 1) API (Next.js)
Start-Process $ps -WindowStyle Minimized -ArgumentList "$opt -Command `"Set-Location 'C:\Dasco1n'; pnpm dev`""

# 2) HTTPS proxy (https://localhost:8443 → http://localhost:3000)
Start-Process $ps -WindowStyle Minimized -ArgumentList "$opt -Command `"npx local-ssl-proxy --source 8443 --target 3000`""

# 3) Discord bot
Start-Process $ps -WindowStyle Minimized -ArgumentList "$opt -Command `"Set-Location 'C:\Dasco1n\bots\discord'; pnpm i; pnpm run register; pnpm run dev`""

# 4) Twitch bot
Start-Process $ps -WindowStyle Minimized -ArgumentList "$opt -Command `"Set-Location 'C:\Dasco1n\bots\twitch'; pnpm i; pnpm dev`""
