<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Simulation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function auditLog(Request $request): JsonResponse
    {
        $this->ensureAdmin($request);

        return response()->json(
            AuditLog::orderBy('id', 'desc')->limit(100)->get()
        );
    }

    public function simulations(Request $request): JsonResponse
    {
        $this->ensureAdmin($request);

        return response()->json(
            Simulation::with('product.business')->latest()->limit(100)->get()
        );
    }

    private function ensureAdmin(Request $request): void
    {
        abort_unless($request->user()?->isAdmin(), 403, 'Se requiere rol de administrador.');
    }
}
