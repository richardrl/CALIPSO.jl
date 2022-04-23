function residual!(data::SolverData, problem::ProblemData, idx::Indices, solution::Point, κ, ρ, λ)
    # duals 
    y = solution.equality_dual
    z = solution.cone_dual

    # slacks 
    r = solution.equality_slack
    s = solution.cone_slack
    t = solution.cone_slack_dual

    # reset
    res = data.residual.all 
    fill!(res, 0.0)

    # gradient of Lagrangian 
    data.residual.variables .= problem.objective_gradient_variables

    for (i, ii) in enumerate(idx.variables)
        res[ii] += problem.equality_dual_jacobian_variables[i] 
        res[ii] += problem.cone_dual_jacobian_variables[i]
    end
    
    # λ + ρr - y 
    for (i, ii) in enumerate(idx.equality_slack) 
        res[ii] = λ[i] + ρ[1] * r[i] - y[i]
    end

    # -z - t
    for (i, ii) in enumerate(idx.cone_slack)
        res[ii] = -z[i] - t[i]
    end

    # equality 
    data.residual.equality_dual .= problem.equality_constraint
    for (i, ii) in enumerate(idx.equality_dual)
        res[ii] -= r[i]
    end

    # cone 
    data.residual.cone_dual .= problem.cone_constraint 
    for (i, ii) in enumerate(idx.cone_dual) 
        res[ii] -= s[i]
    end

    # s ∘ t - κ e
    for (i, ii) in enumerate(idx.cone_slack_dual) 
        res[ii] = problem.cone_product[i] - κ[1] * problem.cone_target[i]
    end

    return 
end

function residual_symmetric!(residual_symmetric, residual, matrix, idx::Indices)
    # reset
    fill!(residual_symmetric, 0.0)

    rx = residual.variables
    rr = residual.equality_slack
    rs = residual.cone_slack
    ry = residual.equality_dual
    rz = residual.cone_dual
    rt = residual.cone_slack_dual

    residual_symmetric[idx.variables] = rx
    residual_symmetric[idx.symmetric_equality] = ry
    residual_symmetric[idx.symmetric_cone] = rz

    # equality correction 
    for (i, ii) in enumerate(idx.symmetric_equality)
        residual_symmetric[ii] += rr[i] / matrix[idx.equality_slack[i], idx.equality_slack[i]]
    end
 
    # cone correction (nonnegative)
    for i in idx.cone_nonnegative
        S̄i = matrix[idx.cone_slack_dual[i], idx.cone_slack_dual[i]] 
        Ti = matrix[idx.cone_slack_dual[i], idx.cone_slack[i]]
        Pi = matrix[idx.cone_slack[i], idx.cone_slack[i]] 
        residual_symmetric[idx.symmetric_cone[i]] += (rt[i] + S̄i * rs[i]) / (Ti + S̄i * Pi)
    end

    # cone correction (second-order)
    for idx_soc in idx.cone_second_order 
        C̄t = @views matrix[idx.cone_slack_dual[idx_soc], idx.cone_slack_dual[idx_soc]] 
        Cs = @views matrix[idx.cone_slack_dual[idx_soc], idx.cone_slack[idx_soc]]
        P  = @views matrix[idx.cone_slack[idx_soc], idx.cone_slack[idx_soc]] 
        residual_symmetric[idx.symmetric_cone[idx_soc]] += (Cs + C̄t * P) \ (C̄t * rt[idx_soc] + rt[idx_soc])
    end

    return 
end
