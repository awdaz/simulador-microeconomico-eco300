<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Simulation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $simulations = Simulation::where('user_id', $userId)->latest()->get();
        $latest = $simulations->first();

        $productCount = Product::whereHas('business', function ($query) use ($userId) {
            $query->where('user_id', $userId);
        })->count();

        return response()->json([
            'totals' => [
                'simulations' => $simulations->count(),
                'products' => $productCount,
            ],
            'latest_simulation' => $latest
                ? $latest->load(['product.business', 'results'])
                : null,
            'recent_simulations' => $simulations->take(5)->load('product'),
        ]);
    }
}
