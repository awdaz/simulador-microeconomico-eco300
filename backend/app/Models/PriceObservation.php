<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PriceObservation extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'product_id',
        'price',
        'quantity_demanded',
        'observed_at',
        'source',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'quantity_demanded' => 'integer',
            'observed_at' => 'date:Y-m-d',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
