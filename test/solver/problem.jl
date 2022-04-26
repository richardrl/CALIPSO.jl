@testset "Solver: Problem" begin
    # dimensions 
    num_variables = 10 
    num_equality = 5 
    num_cone = 5
    num_parameters = 0

    # methods
    objective, equality, inequality, flag = CALIPSO.generate_random_qp(num_variables, num_equality, num_cone);

    # solver
    methods = ProblemMethods(num_variables, num_parameters, objective, equality, inequality)
    solver = Solver(methods, num_variables, num_parameters, num_equality, num_cone)

    solver.solution.variables .= randn(num_variables)
    solver.solution.equality_slack .= rand(num_equality)
    solver.solution.cone_slack .= rand(num_cone)
    solver.solution.equality_dual .= randn(num_equality)
    solver.solution.cone_dual .= randn(num_cone)
    solver.solution.cone_slack_dual .= rand(num_cone) 

    w = solver.solution.all 
    x = solver.solution.variables
    r = solver.solution.equality_slack
    s = solver.solution.cone_slack
    y = solver.solution.equality_dual
    z = solver.solution.cone_dual
    t = solver.solution.cone_slack_dual

    θ = solver.parameters

    κ = [0.17]
    ρ = [52.0]
    λ = randn(num_equality)
    ϵp = 0.12
    ϵd = 0.21
    solver.central_path .= κ 
    solver.penalty .= ρ
    solver.dual .= λ
    solver.primal_regularization[1] = ϵp 
    solver.dual_regularization[1] = ϵd 

    reg = [
            ϵp * ones(num_variables);
            ϵp * ones(num_equality);
            ϵp * ones(num_cone);
        -ϵd * ones(num_equality);
        -ϵd * ones(num_cone);
        -ϵd * ones(num_cone);
        ]



    CALIPSO.problem!(solver.problem, solver.methods, solver.indices, solver.solution, solver.parameters,
        objective=true,
        objective_gradient_variables=true,
        objective_jacobian_variables_variables=true,
        equality_constraint=true,
        equality_jacobian_variables=true,
        equality_dual_jacobian_variables=true,
        equality_dual_jacobian_variables_variables=true,
        cone_constraint=true,
        cone_jacobian_variables=true,
        cone_dual_jacobian_variables=true,
        cone_dual_jacobian_variables_variables=true,
    )

    CALIPSO.cone!(solver.problem, solver.cone_methods, solver.indices, solver.solution,
        product=true,
        jacobian=true,
        target=true,
    )

    CALIPSO.residual_jacobian_variables!(solver.data, solver.problem, solver.indices, κ, ρ, λ, ϵp, ϵd)

    rank(solver.data.jacobian_variables)

    CALIPSO.residual_jacobian_variables_symmetric!(solver.data.jacobian_variables_symmetric, solver.data.jacobian_variables, solver.indices, 
        solver.problem.second_order_jacobians, solver.problem.second_order_jacobians_inverse)

    rank(solver.data.jacobian_variables_symmetric)

    CALIPSO.residual!(solver.data, solver.problem, solver.indices, solver.solution, κ, ρ, λ)

    CALIPSO.residual_symmetric!(solver.data.residual_symmetric, solver.data.residual, solver.data.jacobian_variables, solver.indices)

    # KKT matrix 
    @test rank(solver.data.jacobian_variables) == solver.dimensions.total
    @test norm(solver.data.jacobian_variables[solver.indices.variables, solver.indices.variables] 
        - (solver.problem.objective_jacobian_variables_variables + solver.problem.equality_dual_jacobian_variables_variables + solver.problem.cone_dual_jacobian_variables_variables + ϵp * I)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.equality_dual, solver.indices.variables] 
        - solver.problem.equality_jacobian_variables) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.variables, solver.indices.equality_dual] 
        - solver.problem.equality_jacobian_variables') < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.equality_dual, solver.indices.equality_dual] 
        -(-ϵd * I)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_dual, solver.indices.variables] 
        - solver.problem.cone_jacobian_variables) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.variables, solver.indices.cone_dual] 
        - solver.problem.cone_jacobian_variables') < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_slack, solver.indices.cone_dual] 
        + I(num_cone)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_dual, solver.indices.cone_slack] 
        + I(num_cone)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_slack, solver.indices.cone_slack_dual] 
        + I(num_cone)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_slack_dual, solver.indices.cone_slack] 
        - Diagonal(solver.solution.cone_slack_dual)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_slack_dual, solver.indices.cone_slack_dual] 
        - (Diagonal(solver.solution.cone_slack) -ϵd * I)) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.equality_slack, solver.indices.equality_dual] 
        + I) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.equality_dual, solver.indices.equality_slack] 
        + I) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.equality_slack, solver.indices.equality_slack] 
        - (ρ[1] +  ϵp) * I) < 1.0e-6
    @test norm(solver.data.jacobian_variables[solver.indices.cone_slack, solver.indices.cone_slack] 
        - (ϵp) * I) < 1.0e-6

    # KKT matrix (symmetric)
    @test rank(solver.data.jacobian_variables_symmetric) == solver.dimensions.symmetric
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.variables, solver.indices.variables] 
        - (solver.problem.objective_jacobian_variables_variables + solver.problem.equality_dual_jacobian_variables_variables + solver.problem.cone_dual_jacobian_variables_variables + ϵp * I)) < 1.0e-6
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.symmetric_equality, solver.indices.variables] 
        - solver.problem.equality_jacobian_variables) < 1.0e-6
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.variables, solver.indices.symmetric_equality] 
        - solver.problem.equality_jacobian_variables') < 1.0e-6
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.symmetric_equality, solver.indices.symmetric_equality] 
        -(-1.0 / (ρ[1] + ϵp) * I(num_equality) - ϵd * I)) < 1.0e-6
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.symmetric_cone, solver.indices.variables] 
        - solver.problem.cone_jacobian_variables) < 1.0e-6
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.variables, solver.indices.symmetric_cone] 
        - solver.problem.cone_jacobian_variables') < 1.0e-6
    @test norm(solver.data.jacobian_variables_symmetric[solver.indices.symmetric_cone, solver.indices.symmetric_cone] 
        - Diagonal(-1.0 * (s .- ϵd) ./ (t + (s .- ϵd) * ϵp) .- ϵd)) < 1.0e-6

    # residual 
    @test norm(solver.data.residual.all[solver.indices.variables] 
        - (solver.problem.objective_gradient_variables + solver.problem.equality_jacobian_variables' * solver.solution.equality_dual + solver.problem.cone_jacobian_variables' * solver.solution.cone_dual)) < 1.0e-6

    @test norm(solver.data.residual.all[solver.indices.equality_slack] 
        - (λ + ρ[1] * solver.solution.equality_slack - solver.solution.equality_dual)) < 1.0e-6

    @test norm(solver.data.residual.all[solver.indices.cone_slack] 
    - (-solver.solution.cone_dual - solver.solution.cone_slack_dual)) < 1.0e-6

    @test norm(solver.data.residual.all[solver.indices.equality_dual] 
        - (solver.problem.equality_constraint - solver.solution.equality_slack)) < 1.0e-6

    @test norm(solver.data.residual.all[solver.indices.cone_dual] 
        - (solver.problem.cone_constraint - solver.solution.cone_slack)) < 1.0e-6

    @test norm(solver.data.residual.all[solver.indices.cone_slack_dual] 
        - (solver.solution.cone_slack .* solver.solution.cone_slack_dual .- κ[1])) < 1.0e-6

    # residual symmetric
    rs = solver.data.residual.all[solver.indices.cone_slack]
    rt = solver.data.residual.all[solver.indices.cone_slack_dual]

    @test norm(solver.data.residual_symmetric.variables 
        - (solver.problem.objective_gradient_variables + solver.problem.equality_jacobian_variables' * solver.solution.equality_dual + solver.problem.cone_jacobian_variables' * solver.solution.cone_dual)) < 1.0e-6
    @test norm(solver.data.residual_symmetric.equality 
        - (solver.problem.equality_constraint - solver.solution.equality_slack + solver.data.residual.all[solver.indices.equality_slack] ./ (ρ[1] + ϵp))) < 1.0e-6
    @test norm(solver.data.residual_symmetric.cone 
        - (solver.problem.cone_constraint - solver.solution.cone_slack + (rt + (s .- ϵd) .* rs) ./ (t + (s .- ϵd) * ϵp))) < 1.0e-6

    # step
    fill!(solver.data.residual.all, 0.0)
    CALIPSO.residual!(solver.data, solver.problem, solver.indices, solver.solution, κ, ρ, λ)
    CALIPSO.search_direction_nonsymmetric!(solver.data.step, solver.data)
    Δ = deepcopy(solver.data.step)

    CALIPSO.search_direction_symmetric!(solver.data.step, solver.data.residual, solver.data.jacobian_variables, 
        solver.data.step_symmetric, solver.data.residual_symmetric, solver.data.jacobian_variables_symmetric, 
        solver.indices, solver.linear_solver)
    Δ_symmetric = deepcopy(solver.data.step)

    @test norm(Δ.all - Δ_symmetric.all) < 1.0e-6

    # iterative refinement

    noisy_step = deepcopy(solver.data.step)
    noisy_step.all .= solver.data.step.all + randn(length(solver.data.step.all))
    # @show norm(solver.data.residual.all - solver.data.jacobian_variables * noisy_step)
    CALIPSO.iterative_refinement!(noisy_step, solver)
    @test norm(solver.data.residual.all - solver.data.jacobian_variables * noisy_step.all) < solver.options.iterative_refinement_tolerance
end
