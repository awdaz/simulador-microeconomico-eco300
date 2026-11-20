<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\ObservationController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\SimulationController;
use Illuminate\Support\Facades\Route;

// ------------------------------------------------------------
// Publico
// ------------------------------------------------------------
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// ------------------------------------------------------------
// Autenticado (Sanctum Bearer token)
// ------------------------------------------------------------
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    Route::get('/dashboard', [DashboardController::class, 'index']);

    Route::get('/products', [ProductController::class, 'index']);
    Route::get('/products/{product}', [ProductController::class, 'show']);
    Route::get('/products/{product}/estimate', [ProductController::class, 'estimate']);

    Route::get('/products/{product}/observations', [ObservationController::class, 'index']);
    Route::post('/products/{product}/observations', [ObservationController::class, 'store']);
    Route::delete('/products/{product}/observations/{observation}', [ObservationController::class, 'destroy']);

    Route::get('/simulations', [SimulationController::class, 'index']);
    Route::post('/simulations', [SimulationController::class, 'store']);
    Route::get('/simulations/{simulation}', [SimulationController::class, 'show']);
    Route::get('/simulations/{simulation}/curve', [SimulationController::class, 'curve']);
    Route::post('/simulations/{simulation}/refresh', [SimulationController::class, 'refresh']);
    Route::delete('/simulations/{simulation}', [SimulationController::class, 'destroy']);

    Route::prefix('/admin')->group(function () {
        Route::get('/audit-log', [AdminController::class, 'auditLog']);
        Route::get('/simulations', [AdminController::class, 'simulations']);
    });
});
