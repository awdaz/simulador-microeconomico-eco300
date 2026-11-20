<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Simulation extends Model
{
    protected $fillable = [
        'user_id',
        'product_id',
        'name',
        'intercept_a',
        'slope_b',
        'variable_cost',
        'fixed_cost',
        'optimal_price',
        'optimal_quantity',
        'max_profit',
        'epd',
        'demand_type',
        'break_even_min',
        'break_even_max',
        'price_min',
        'price_max',
        'price_step',
    ];

    protected function casts(): array
    {
        return [
            'intercept_a' => 'decimal:4',
            'slope_b' => 'decimal:4',
            'variable_cost' => 'decimal:2',
            'fixed_cost' => 'decimal:2',
            'optimal_price' => 'decimal:2',
            'optimal_quantity' => 'decimal:4',
            'max_profit' => 'decimal:2',
            'epd' => 'decimal:4',
            'break_even_min' => 'decimal:2',
            'break_even_max' => 'decimal:2',
            'price_min' => 'decimal:2',
            'price_max' => 'decimal:2',
            'price_step' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function results(): HasMany
    {
        return $this->hasMany(SimulationResult::class)->orderBy('price');
    }
}
