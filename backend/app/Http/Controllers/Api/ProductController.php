<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $products = Product::with('business')
            ->whereHas('business', function ($query) use ($request) {
                $query->where('user_id', $request->user()->id);
            })
            ->orderBy('id')
            ->get();

        return response()->json($products);
    }

    public function show(Request $request, Product $product): JsonResponse
    {
        $this->ensureOwner($request, $product);

        return response()->json(
            $product->load(['business', 'observations', 'costHistory'])
        );
    }

    public function estimate(Request $request, Product $product): JsonResponse
    {
        $this->ensureOwner($request, $product);

        $estimate = DB::selectOne(
            'SELECT a, b FROM fn_estimar_demanda(?)',
            [$product->id]
        );

        return response()->json([
            'product_id' => $product->id,
            'intercept_a' => $estimate->a,
            'slope_b' => $estimate->b,
            'equation' => sprintf('Q = %.4f - %.4fP', $estimate->a, $estimate->b),
            'observations' => $product->observations()->orderBy('price')->get(),
        ]);
    }

    private function ensureOwner(Request $request, Product $product): void
    {
        abort_unless($product->business->user_id === $request->user()->id, 403, 'No tienes acceso a este producto.');
    }
}
