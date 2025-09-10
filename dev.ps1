# scripts/dev.ps1
param([switch]$ResetDb)

Write-Host "Ensuring Prisma client..." -ForegroundColor Cyan
npm run db:gen | Out-Host

if ($ResetDb) {
  Write-Host "Resetting DB and seeding..." -ForegroundColor Yellow
  npm run db:reset | Out-Host
}

Write-Host "Starting Next dev server on :3000..." -ForegroundColor Green
npm run dev
