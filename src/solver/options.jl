Base.@kwdef mutable struct Options{T}
    residual_norm::T=1.0
    residual_tolerance::T=1.0e-6
    max_outer_iterations::Int=15
    max_residual_iterations::Int=100
    scaling_line_search::T=0.5
    max_residual_line_search::Int=25
    max_cone_line_search::Int=25
    max_second_order_correction::Int=5
    iterative_refinement::Bool=false
    max_iterative_refinement::Int=10
    iterative_refinement_tolerance=1.0e-8
    central_path_initial::T=1.0
    scaling_central_path::T=0.1 
    central_path_tolerance::T=1.0e-5
    penalty_initial::T=1.0 
    scaling_penalty::T=10.0
    dual_initial::T=0.0
    dual_tolerance::T=1.0e-5
    min_regularization::T = 1.0e-20
    primal_regularization_initial::T = 1.0e-4
    max_regularization::T = 1.0e40
    dual_regularization::T = 1.0e-8
    scaling_regularization_initial::T = 100.0
    scaling_regularization::T = 8.0
    scaling_regularization_last::T = 1.0 / 3.0
    verbose::Bool=true
end