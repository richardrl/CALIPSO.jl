Base.@kwdef mutable struct Options{T}
    residual_norm::T=1.0
    constraint_norm::T=1.0
    residual_tolerance::T=1.0e-4
    max_outer_iterations::Int=15
    max_residual_iterations::Int=100
    scaling_line_search::T=0.5
    max_residual_line_search::Int=25
    max_cone_line_search::Int=25
    max_second_order_correction::Int=5
    iterative_refinement::Bool=true
    max_iterative_refinement::Int=10
    min_iterative_refinement::Int=1
    iterative_refinement_tolerance=1.0e-8
    central_path_initial::T=1.0
    central_path_update_tolerance::T=10.0
    central_path_convergence_tolerance::T=1.0e-5
    central_path_scaling::T = 0.2
    central_path_exponent::T = 1.5
    penalty_initial::T=1.0
    scaling_penalty::T=10.0
    dual_initial::T=0.0
    optimality_tolerance::T=1.0e-3
    equality_tolerance::T=1.0e-3
    complementarity_tolerance::T=1.0e-3
    min_regularization::T=1.0e-20
    primal_regularization_initial::T=1.0e-4
    max_regularization::T=1.0e40
    dual_regularization::T=1.0e-8
    scaling_regularization_initial::T=100.0
    scaling_regularization::T=8.0
    scaling_regularization_last::T=(1.0 / 3.0)
    min_central_path::T=1.0e-8 
    max_penalty::T=1.0e8
    armijo_tolerance::T=1.0e-4
    constraint_hessian::Bool=true
    linear_solver::Symbol=:QDLDL
    update_factorization::Bool=true
    differentiate::Bool=true
    verbose::Bool=true
end
