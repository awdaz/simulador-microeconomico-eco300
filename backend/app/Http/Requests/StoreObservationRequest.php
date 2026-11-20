<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreObservationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'price' => ['required', 'numeric', 'min:0.01', 'max:9999999999'],
            'quantity_demanded' => ['required', 'integer', 'min:0'],
            'observed_at' => ['required', 'date'],
            'source' => ['sometimes', 'in:historico,estimado'],
        ];
    }
}
