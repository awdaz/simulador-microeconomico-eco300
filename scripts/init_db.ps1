# ============================================================
# init_db.ps1 - Levanta la BD, aplica SQL y verifica el caso base
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\init_db.ps1
# ============================================================
$ErrorActionPreference = 'Stop'

Set-Location -Path (Join-Path $PSScriptRoot '..')

function Assert-Exit {
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        throw "Comando fallido con codigo $LASTEXITCODE"
    }
}

if (-not (Test-Path '.env')) {
    Copy-Item '.env.example' '.env'
    Write-Host '[0/5] Creado .env desde .env.example'
}

Write-Host '[1/5] Levantando PostgreSQL y pgAdmin...'
docker compose up -d postgres pgadmin
Assert-Exit

Write-Host '[2/5] Esperando a que PostgreSQL este healthy...'
$status = ''
for ($i = 0; $i -lt 40; $i++) {
    $status = (docker inspect --format '{{.State.Health.Status}}' simeco-postgres 2>$null) | Out-String
    $status = $status.Trim()
    if ($status -eq 'healthy') { break }
    Start-Sleep -Seconds 2
}
if ($status -ne 'healthy') {
    throw "PostgreSQL no alcanzo el estado 'healthy' (estado actual: '$status')"
}
Write-Host '      PostgreSQL listo.'

Write-Host '[3/5] Aplicando esquema, funciones, PA, triggers y seeders...'
docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/00_run_all.sql'
Assert-Exit

Write-Host '[4/5] Verificando el caso de estudio...'
docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/99_verify.sql'
Assert-Exit

Write-Host '[5/5] Listo.'
Write-Host ''
Write-Host '  pgAdmin : http://localhost:5050  (admin@economia.com / admin)'
Write-Host '  Postgres: localhost:5433         (economia / economia / economia)'
