<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductCostHistory extends Model
{
    protected $table = 'product_cost_history';

    public $timestamps = false;

    protected $fillable = [
        'product_id',
        'old_cost',
        'new_cost',
    ];

    protected function casts(): array
    {
        return [
            'old_cost' => 'decimal:2',
            'new_cost' => 'decimal:2',
            'changed_at' => 'datetime',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
