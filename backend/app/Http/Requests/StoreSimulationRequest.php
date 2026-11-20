<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreSimulationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'name' => ['required', 'string', 'max:150'],
            'price_min' => ['required', 'numeric', 'min:0.01'],
            'price_max' => ['required', 'numeric', 'gt:price_min'],
            'price_step' => ['required', 'numeric', 'min:0.01'],
            'cv_override' => ['nullable', 'numeric', 'min:0'],
            'cf_override' => ['nullable', 'numeric', 'min:0'],
        ];
    }

    public function messages(): array
    {
        return [
            'price_max.gt' => 'El precio maximo debe ser mayor al precio minimo.',
            'exists' => 'El producto seleccionado no existe.',
        ];
    }
}
