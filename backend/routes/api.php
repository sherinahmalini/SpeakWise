<?php

use App\Http\Controllers\AssessmentController;
use Illuminate\Support\Facades\Route;

Route::get('/test', function () {
    return response()->json([
        'success' => true,
        'message' => 'SpeakWise API is working!',
    ]);
});

Route::post('/analyze', [
    AssessmentController::class,
    'analyze',
]);

Route::post('/practice/presentation', [
    AssessmentController::class,
    'processPresentation',
]);

Route::post('/practice/suggested-speech', [
    AssessmentController::class,
    'suggestedSpeech',
]);

Route::post('/practice/analyze', [
    AssessmentController::class,
    'analyzePractice',
]);




