# dimensions 
num_variables = 10 
num_equality = 5 
num_cone = 5

x = randn(num_variables)
r = rand(num_equality)
s = rand(num_cone)
y = randn(num_equality)
z = randn(num_cone)
t = rand(num_cone) 

w = [x; r; s; y; z; t]
κ = [1.0]
ρ = [1.0]
λ = randn(num_equality)
ϵp = 0.12 #1.0e-5 
ϵd = 0.21 #1.0e-6 

reg = [
        ϵp * ones(num_variables);
        ϵp * ones(num_equality);
        ϵp * ones(num_cone);
       -ϵd * ones(num_equality);
       -ϵd * ones(num_cone);
       -ϵd * ones(num_cone);
      ]


# methods
objective, equality, cone, flag = generate_random_qp(num_variables, num_equality, num_cone);

# solver
methods = ProblemMethods(num_variables, objective, equality, cone)
solver = Solver(methods, num_variables, num_equality, num_cone)

problem!(solver.problem, solver.methods, solver.indices, w)

matrix!(solver.data, solver.problem, solver.indices, w, κ, ρ, λ, ϵp, ϵd)

matrix_symmetric!(solver.data.matrix_symmetric, solver.data.matrix, solver.indices)

residual!(solver.data, solver.problem, solver.indices, w, κ, ρ, λ)

residual_symmetric!(solver.data.residual_symmetric, solver.data.residual, solver.data.matrix, solver.indices)

# KKT matrix 
@test rank(solver.data.matrix) == solver.dimensions.total
@test norm(solver.data.matrix[solver.indices.variables, solver.indices.variables] 
    - (solver.problem.objective_hessian + solver.problem.equality_hessian + solver.problem.cone_hessian + ϵp * I)) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.equality_dual, solver.indices.variables] 
    - solver.problem.equality_jacobian) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.variables, solver.indices.equality_dual] 
    - solver.problem.equality_jacobian') < 1.0e-6
@test norm(solver.data.matrix[solver.indices.equality_dual, solver.indices.equality_dual] 
    -(-ϵd * I)) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_dual, solver.indices.variables] 
    - solver.problem.cone_jacobian) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.variables, solver.indices.cone_dual] 
    - solver.problem.cone_jacobian') < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_slack, solver.indices.cone_dual] 
    + I(num_cone)) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_dual, solver.indices.cone_slack] 
    + I(num_cone)) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_slack, solver.indices.cone_slack_dual] 
    + I(num_cone)) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_slack_dual, solver.indices.cone_slack] 
    - Diagonal(w[solver.indices.cone_slack_dual])) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_slack_dual, solver.indices.cone_slack_dual] 
    - (Diagonal(w[solver.indices.cone_slack]) -ϵd * I)) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.equality_slack, solver.indices.equality_dual] 
    + I) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.equality_dual, solver.indices.equality_slack] 
    + I) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.equality_slack, solver.indices.equality_slack] 
    - (ρ[1] +  ϵp) * I) < 1.0e-6
@test norm(solver.data.matrix[solver.indices.cone_slack, solver.indices.cone_slack] 
    - (ϵp) * I) < 1.0e-6

# KKT matrix (symmetric)
@test rank(solver.data.matrix_symmetric) == solver.dimensions.symmetric
@test norm(solver.data.matrix_symmetric[solver.indices.variables, solver.indices.variables] 
    - (solver.problem.objective_hessian + solver.problem.equality_hessian + solver.problem.cone_hessian + ϵp * I)) < 1.0e-6
@test norm(solver.data.matrix_symmetric[solver.indices.symmetric_equality, solver.indices.variables] 
    - solver.problem.equality_jacobian) < 1.0e-6
@test norm(solver.data.matrix_symmetric[solver.indices.variables, solver.indices.symmetric_equality] 
    - solver.problem.equality_jacobian') < 1.0e-6
@test norm(solver.data.matrix_symmetric[solver.indices.symmetric_equality, solver.indices.symmetric_equality] 
    -(-1.0 / (ρ[1] + ϵp) * I(num_equality) - ϵd * I)) < 1.0e-6
@test norm(solver.data.matrix_symmetric[solver.indices.symmetric_cone, solver.indices.variables] 
    - solver.problem.cone_jacobian) < 1.0e-6
@test norm(solver.data.matrix_symmetric[solver.indices.variables, solver.indices.symmetric_cone] 
    - solver.problem.cone_jacobian') < 1.0e-6
@test norm(solver.data.matrix_symmetric[solver.indices.symmetric_cone, solver.indices.symmetric_cone] 
    - Diagonal(-1.0 * (s .- ϵd) ./ (t + (s .- ϵd) * ϵp) .- ϵd)) < 1.0e-6

# residual 
@test norm(solver.data.residual[solver.indices.variables] 
    - (solver.problem.objective_gradient + solver.problem.equality_jacobian' * w[solver.indices.equality_dual] + solver.problem.cone_jacobian' * w[solver.indices.cone_dual])) < 1.0e-6

@test norm(solver.data.residual[solver.indices.equality_slack] 
    - (λ + ρ[1] * w[solver.indices.equality_slack] - w[solver.indices.equality_dual])) < 1.0e-6

@test norm(solver.data.residual[solver.indices.cone_slack] 
- (-w[solver.indices.cone_dual] - w[solver.indices.cone_slack_dual])) < 1.0e-6

@test norm(solver.data.residual[solver.indices.equality_dual] 
    - (solver.problem.equality - w[solver.indices.equality_slack])) < 1.0e-6

@test norm(solver.data.residual[solver.indices.cone_dual] 
    - (solver.problem.cone - w[solver.indices.cone_slack])) < 1.0e-6

@test norm(solver.data.residual[solver.indices.cone_slack_dual] 
    - (w[solver.indices.cone_slack] .* w[solver.indices.cone_slack_dual] .- κ[1])) < 1.0e-6

# residual symmetric
rs = solver.data.residual[solver.indices.cone_slack]
rt = solver.data.residual[solver.indices.cone_slack_dual]

@test norm(solver.data.residual_symmetric[solver.indices.variables] 
    - (solver.problem.objective_gradient + solver.problem.equality_jacobian' * w[solver.indices.equality_dual] + solver.problem.cone_jacobian' * w[solver.indices.cone_dual])) < 1.0e-6
@test norm(solver.data.residual_symmetric[solver.indices.symmetric_equality] 
    - (solver.problem.equality - w[solver.indices.equality_slack] + solver.data.residual[solver.indices.equality_slack] ./ (ρ[1] + ϵp))) < 1.0e-6
@test norm(solver.data.residual_symmetric[solver.indices.symmetric_cone] 
    - (solver.problem.cone - w[solver.indices.cone_slack] + (rt + (s .- ϵd) .* rs) ./ (t + (s .- ϵd) * ϵp))) < 1.0e-6

# step
fill!(solver.data.residual, 0.0)
residual!(solver.data, solver.problem, solver.indices, w, κ, ρ, λ)
search_direction!(solver.data.step, solver.data)
Δ = deepcopy(solver.data.step)

search_direction_symmetric!(solver.data.step, solver.data.residual, solver.data.matrix, 
    solver.data.step_symmetric, solver.data.residual_symmetric, solver.data.matrix_symmetric, 
    solver.indices, solver.linear_solver)
Δ_symmetric = deepcopy(solver.data.step)

@test norm(Δ - Δ_symmetric) < 1.0e-6

# iterative refinement
noisy_step = solver.data.step + randn(length(solver.data.step))
@show norm(solver.data.residual - solver.data.matrix * noisy_step)
iterative_refinement!(noisy_step, solver)
@test norm(solver.data.residual - solver.data.matrix * noisy_step) < solver.options.iterative_refinement_tolerance

# second order correction 
step_copy = deepcopy(solver.data.step)
# for i = 1:solver.options.max_second_order_correction
problem!(solver.problem, solver.methods, solver.indices, solver.candidate,
    gradient=false,
    constraint=true,
    jacobian=false,
    hessian=false)

solver.data.residual[solver.indices.equality_dual] .+= solver.problem.equality + 1.0 / solver.penalty[1] * (solver.dual - solver.candidate[solver.indices.equality_dual])
solver.data.residual[solver.indices.cone_dual] .+= (solver.problem.cone - solver.candidate[solver.indices.cone_slack])

search_direction_symmetric!(solver.data.step, solver.data.residual, solver.data.matrix, 
    solver.data.step_symmetric, solver.data.residual_symmetric, solver.data.matrix_symmetric, 
    solver.indices, solver.linear_solver)

solver.options.iterative_refinement && iterative_refinement!(solver.data.step, solver)

solver.candidate .= solver.variables - step_size * solver.data.step
# end
# @show norm(solver.data.step - step_copy)
