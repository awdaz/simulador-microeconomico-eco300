<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Product extends Model
{
    protected $fillable = [
        'business_id',
        'name',
        'sku',
        'unit',
        'variable_cost_unit',
        'current_stock',
        'active',
    ];

    protected function casts(): array
    {
        return [
            'variable_cost_unit' => 'decimal:2',
            'current_stock' => 'integer',
            'active' => 'boolean',
        ];
    }

    public function business(): BelongsTo
    {
        return $this->belongsTo(Business::class);
    }

    public function observations(): HasMany
    {
        return $this->hasMany(PriceObservation::class);
    }

    public function simulations(): HasMany
    {
        return $this->hasMany(Simulation::class);
    }

    public function costHistory(): HasMany
    {
        return $this->hasMany(ProductCostHistory::class);
    }
}
