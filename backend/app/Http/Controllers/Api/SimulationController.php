<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSimulationRequest;
use App\Models\Product;
use App\Models\Simulation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SimulationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $simulations = Simulation::with('product.business')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->paginate(15);

        return response()->json($simulations);
    }

    public function store(StoreSimulationRequest $request): JsonResponse
    {
        $data = $request->validated();
        $product = Product::findOrFail($data['product_id']);

        abort_unless($product->business->user_id === $request->user()->id, 403, 'No tienes acceso a este producto.');

        $simulationId = DB::selectOne(
            'SELECT fn_run_simulation(?, ?, ?, ?, ?, ?, ?, ?) AS id',
            [
                $request->user()->id,
                $product->id,
                $data['name'],
                $data['price_min'],
                $data['price_max'],
                $data['price_step'],
                $data['cv_override'] ?? null,
                $data['cf_override'] ?? null,
            ]
        )->id;

        $simulation = Simulation::with(['product.business', 'results'])->findOrFail($simulationId);

        return response()->json($simulation, 201);
    }

    public function show(Request $request, Simulation $simulation): JsonResponse
    {
        $this->ensureOwner($request, $simulation);

        return response()->json($simulation->load(['product.business', 'results']));
    }

    public function curve(Request $request, Simulation $simulation): JsonResponse
    {
        $this->ensureOwner($request, $simulation);

        return response()->json($simulation->results()->orderBy('price')->get());
    }

    public function refresh(Request $request, Simulation $simulation): JsonResponse
    {
        $this->ensureOwner($request, $simulation);

        DB::statement('CALL sp_refresh_simulation(?)', [$simulation->id]);

        return response()->json(
            $simulation->fresh()->load(['product.business', 'results'])
        );
    }

    public function destroy(Request $request, Simulation $simulation): JsonResponse
    {
        $this->ensureOwner($request, $simulation);

        $simulation->delete();

        return response()->json(['message' => 'Simulacion eliminada.']);
    }

    private function ensureOwner(Request $request, Simulation $simulation): void
    {
        abort_unless($simulation->user_id === $request->user()->id, 403, 'No tienes acceso a esta simulacion.');
    }
}
