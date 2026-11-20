<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreObservationRequest;
use App\Models\PriceObservation;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ObservationController extends Controller
{
    public function index(Request $request, Product $product): JsonResponse
    {
        $this->ensureOwner($request, $product);

        return response()->json(
            $product->observations()->orderBy('price')->get()
        );
    }

    public function store(StoreObservationRequest $request, Product $product): JsonResponse
    {
        $this->ensureOwner($request, $product);

        $observation = $product->observations()->create($request->validated());

        return response()->json($observation, 201);
    }

    public function destroy(Request $request, Product $product, PriceObservation $observation): JsonResponse
    {
        $this->ensureOwner($request, $product);

        abort_unless($observation->product_id === $product->id, 404, 'La observacion no pertenece al producto.');

        $observation->delete();

        return response()->json(['message' => 'Observacion eliminada.']);
    }

    private function ensureOwner(Request $request, Product $product): void
    {
        abort_unless($product->business->user_id === $request->user()->id, 403, 'No tienes acceso a este producto.');
    }
}
