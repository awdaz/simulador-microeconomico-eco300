<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SimulationResult extends Model
{
    protected $fillable = [
        'simulation_id',
        'price',
        'quantity',
        'revenue',
        'total_cost',
        'profit',
        'epd',
        'is_optimal',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'quantity' => 'decimal:4',
            'revenue' => 'decimal:2',
            'total_cost' => 'decimal:2',
            'profit' => 'decimal:2',
            'epd' => 'decimal:4',
            'is_optimal' => 'boolean',
        ];
    }

    public function simulation(): BelongsTo
    {
        return $this->belongsTo(Simulation::class);
    }
}
