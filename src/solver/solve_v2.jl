# num_variables = 10 
# num_equality = 5 
# num_inequality = num_variables

# A = rand(num_equality, num_inequality) 
# x̄ = max.(randn(num_variables), 1.0e-2) 
# b = A * x̄

# # equations
# obj(x) = dot(x, x) + dot(ones(num_variables), x)
# eq(x) = A * x - b 
# ineq(x) = x

# # gradients 
# methods = ProblemMethods(num_variables, obj, eq, ineq)
# solver = Solver(methods, num_variables, num_equality, num_inequality)

function solve_v2!(solver)
    # initialize
    initialize_slacks!(solver)
    initialize_duals!(solver)
    initialize_interior_point!(solver.central_path, solver.options)
    initialize_augmented_lagrangian!(solver.penalty, solver.dual, solver.options)

    # indices 
    indices = solver.indices 

    # variables 
    variables = solver.variables 
    x = @views variables[indices.variables] 
    r = @views variables[indices.equality_slack] 
    s = @views variables[indices.inequality_slack] 
    y = @views variables[indices.equality_dual] 
    z = @views variables[indices.inequality_dual] 
    t = @views variables[indices.inequality_slack_dual] 

    # candidate
    candidate = solver.candidate
    x̂ = @views candidate[indices.variables] 
    r̂ = @views candidate[indices.equality_slack] 
    ŝ = @views candidate[indices.inequality_slack] 
    ŷ = @views candidate[indices.equality_dual] 
    ẑ = @views candidate[indices.inequality_dual] 
    t̂ = @views candidate[indices.inequality_slack_dual] 

    # solver data 
    data = solver.data

    # search direction 
    step = data.step
    Δx = @views step[indices.variables] 
    Δr = @views step[indices.equality_slack]
    Δs = @views step[indices.inequality_slack]
    Δy = @views step[indices.equality_dual]
    Δz = @views step[indices.inequality_dual] 
    Δt = @views step[indices.inequality_slack_dual] 
    Δp = @views step[indices.primals]

    # constraints 
    constraint_violation = solver.data.constraint_violation

    # problem 
    problem = solver.problem 
    methods = solver.methods

    # barrier + augmented Lagrangian 
    κ = solver.central_path 
    ρ = solver.penalty 
    λ = solver.dual 

    # options 
    options = solver.options 

    # counter
    total_iterations = 1

    for j = 1:options.max_outer_iterations
        for i = 1:options.max_residual_iterations

            options.verbose && println("iter: ($j, $i, $total_iterations)")

            # compute residual 
            problem!(problem, methods, indices, variables,
                gradient=true,
                constraint=true,
                jacobian=true,
                hessian=true)

            M = merit(
                methods.objective(x), 
                x, r, s, κ[1], λ, ρ[1])

            merit_grad = vcat(merit_gradient(
                problem.objective_gradient,  
                x, r, s, κ[1], λ, ρ[1])...)

            residual!(data, problem, indices, variables, κ, ρ, λ)
            res_norm = norm(data.residual, options.residual_norm) / solver.dimensions.total
            options.verbose && println("res: $(res_norm)")

            θ = constraint_violation!(constraint_violation, 
                problem.equality, r, problem.inequality, s, indices,
                norm_type=options.constraint_norm)
            
            options.verbose && println("con: $(θ)")

            # check convergence
            if res_norm < options.residual_tolerance
                break 
            end

            # search direction
            
            inertia_correction!(solver)

            search_direction_symmetric!(step, data.residual, data.matrix, 
                data.step_symmetric, data.residual_symmetric, data.matrix_symmetric, 
                indices, solver.linear_solver)

            options.iterative_refinement && iterative_refinement!(step, solver)

            # step .= jac \ res 

            # line search
            α = 1.0  
            αt = 1.0
            
            # cone search 
            ŝ .= s - α * Δs
            t̂ .= t - αt * Δt 

            cone_iteration = 0
            while any(ŝ .<= 0)
                α = 0.5 * α 
                ŝ .= s - α * Δs
                cone_iteration += 1 
                cone_iteration > options.max_cone_line_search && error("cone search failure")
            end

            cone_iteration = 0
            while any(t̂ .<= 0.0) 
                αt = 0.5 * αt
                t̂ .= t - αt * Δt
                cone_iteration += 1 
                cone_iteration > options.max_cone_line_search && error("cone search failure")
            end

            # decrease search 
            x̂ .= x - α * Δx
            r̂ .= r - α * Δr

            # compute residual 
            problem!(problem, methods, indices, candidate,
                gradient=false,
                constraint=true,
                jacobian=false,
                hessian=false)

            M̂ = merit(methods.objective(x̂), x̂, r̂, ŝ, κ[1], λ, ρ[1])
            θ̂  = constraint_violation!(constraint_violation, 
                problem.equality, r̂, problem.inequality, ŝ, indices,
                norm_type=options.constraint_norm)
            d = options.armijo_tolerance * dot(Δp, merit_grad)

            residual_iteration = 0

            while M̂ > M + α * d && θ̂ > θ
                # decrease step size 
                α = 0.5 * α

                # update candidate
                x̂ .= x - α * Δx
                r̂ .= r - α * Δr
                ŝ .= s - α * Δs

                # compute residual 
                problem!(problem, methods, indices, candidate,
                    gradient=false,
                    constraint=true,
                    jacobian=false,
                    hessian=false)

                M̂ = merit(methods.objective(x̂), x̂, r̂, ŝ, κ[1], λ, ρ[1])
                θ̂  = constraint_violation!(constraint_violation, 
                    problem.equality, r̂, problem.inequality, ŝ, indices,
                    norm_type=options.constraint_norm)

                residual_iteration += 1 
                residual_iteration > options.max_residual_line_search && error("residual search failure")
            end

            options.verbose && println("α = $α")

            # update
            x .= x̂
            r .= r̂
            s .= ŝ 
            y .= y - α * Δy
            z .= z - α * Δz
            t .= t̂
            
            total_iterations += 1
            options.verbose && println("con: $(norm(solver.problem.equality, Inf))")
            options.verbose && println("")
        end

        # convergence
        if norm(problem.equality, Inf) <= options.equality_tolerance && norm(s .* t, Inf) <= options.complementarity_tolerance
            options.verbose && println("solve success!")
            return true 
        # update
        else
            # central-path
            κ[1] = max(options.scaling_central_path * κ[1], options.min_central_path)
            # augmented Lagrangian
            λ .= λ + ρ[1] * r
            ρ[1] = min(options.scaling_penalty * ρ[1], options.max_penalty) 
        end
    end

    # failure
    return false
end

# # initialize 
# x0 = ones(num_variables) 
# initialize!(solver, x0)

# solve_v2!(solver)
