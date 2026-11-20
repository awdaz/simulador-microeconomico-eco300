# ============================================================
# test_api.ps1 - Pruebas de extremo a extremo de la API Laravel
# Requiere: API corriendo en http://127.0.0.1:8000
# ============================================================
$ErrorActionPreference = 'Stop'

$base = 'http://127.0.0.1:8000/api'
function AuthHeader([string]$token) { @{ Authorization = "Bearer $token" } }
function Check([string]$label, [bool]$ok, [string]$detail = '') {
    if ($ok) { Write-Host "  OK  $label $detail" -ForegroundColor Green }
    else { Write-Host "FALLO $label $detail" -ForegroundColor Red; throw "Prueba fallida: $label" }
}

Write-Host "`n==> Autenticacion" -ForegroundColor Cyan
$login = Invoke-RestMethod "$base/login" -Method Post -ContentType 'application/json' `
    -Body '{"email":"admin@economia.test","password":"password123"}'
Check 'login admin' ($login.user.role -eq 'admin') "-> $($login.user.email)"
$token = $login.token

$me = Invoke-RestMethod "$base/me" -Headers (AuthHeader $token)
Check 'GET /me' ($me.email -eq 'admin@economia.test')

Write-Host "`n==> Dashboard y productos" -ForegroundColor Cyan
$dash = Invoke-RestMethod "$base/dashboard" -Headers (AuthHeader $token)
Check 'dashboard case study' ($dash.latest_simulation.epd -eq '1.5000') "-> EPD $($dash.latest_simulation.epd)"

$products = Invoke-RestMethod "$base/products" -Headers (AuthHeader $token)
Check 'productos' (@($products).Count -ge 1) "-> $($products[0].sku)"
$productId = $products[0].id

$estimate = Invoke-RestMethod "$base/products/$productId/estimate" -Headers (AuthHeader $token)
Check 'estimacion demanda' ($estimate.equation -eq 'Q = 1000.0000 - 50.0000P') "-> $($estimate.equation)"

Write-Host "`n==> Observaciones" -ForegroundColor Cyan
$obs = Invoke-RestMethod "$base/products/$productId/observations" -Method Post `
    -Headers (AuthHeader $token) -ContentType 'application/json' `
    -Body '{"price":12,"quantity_demanded":400,"observed_at":"2026-11-20","source":"estimado"}'
Check 'alta observacion' ($obs.id -gt 0) "-> id $($obs.id)"
Invoke-RestMethod "$base/products/$productId/observations/$($obs.id)" -Method Delete `
    -Headers (AuthHeader $token) | Out-Null
Check 'baja observacion' $true

Write-Host "`n==> Simulacion" -ForegroundColor Cyan
$payload = @{
    product_id = $productId
    name       = "Test API $(Get-Date -Format yyyyMMddHHmmss)"
    price_min  = 4
    price_max  = 25
    price_step = 0.5
} | ConvertTo-Json

$sim = Invoke-RestMethod "$base/simulations" -Method Post -Headers (AuthHeader $token) `
    -ContentType 'application/json' -Body $payload
Check 'optimo' ($sim.optimal_price -eq '12.00') "-> P*=$($sim.optimal_price)"
Check 'cantidad' ($sim.optimal_quantity -eq '400.0000') "-> Q*=$($sim.optimal_quantity)"
Check 'beneficio' ($sim.max_profit -eq '1700.00') "-> PI*=$($sim.max_profit)"
Check 'elasticidad' ($sim.demand_type -eq 'elastic') "-> $($sim.demand_type)"

$curve = Invoke-RestMethod "$base/simulations/$($sim.id)/curve" -Headers (AuthHeader $token)
Check 'grilla de precios' (@($curve).Count -eq 43) "-> $(@($curve).Count) filas"

Invoke-RestMethod "$base/simulations/$($sim.id)/refresh" -Method Post `
    -Headers (AuthHeader $token) | Out-Null
Check 'refresh' $true

Invoke-RestMethod "$base/simulations/$($sim.id)" -Method Delete `
    -Headers (AuthHeader $token) | Out-Null
Check 'baja simulacion' $true

Write-Host "`n==> Registro y permisos" -ForegroundColor Cyan
$email = "test$(Get-Random -Maximum 999999)@eco300.test"
$reg = Invoke-RestMethod "$base/register" -Method Post -ContentType 'application/json' -Body (@{
    name                  = 'Usuario Prueba'
    email                 = $email
    password              = 'password123'
    password_confirmation = 'password123'
} | ConvertTo-Json)
Check 'registro rol user' ($reg.user.role -eq 'user')

$denied = 0
try { Invoke-RestMethod "$base/admin/audit-log" -Headers (AuthHeader $reg.token) }
catch { if ($_.Exception.Response) { $denied = [int]$_.Exception.Response.StatusCode } }
Check 'no-admin bloqueado' ($denied -eq 403) "-> HTTP $denied"

$unauth = 0
try { Invoke-RestMethod "$base/simulations" -Headers (AuthHeader 'token-invalido') }
catch { if ($_.Exception.Response) { $unauth = [int]$_.Exception.Response.StatusCode } }
Check 'token invalido' ($unauth -eq 401) "-> HTTP $unauth"

Write-Host "`nTODAS LAS PRUEBAS DE LA API PASARON`n" -ForegroundColor Cyan
