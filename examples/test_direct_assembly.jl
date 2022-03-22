# DirectTrajectoryOptimization.jl environment 

# ## tested w/ pendulum example

# ## assemble full system 

# dimensions
nz = solver.nlp.num_variables
ny = solver.nlp.num_constraint
nw = nz + ny
nj = solver.nlp.num_jacobian
nh = solver.nlp.num_hessian_lagrangian

# variables
z = rand(nz)
y = rand(ny)

w = zeros(nw)
for idx in solver.nlp.indices.states
    w[idx] = 
end

# data
obj_grad = zeros(nz)
con = zeros(ny)
con_jac = zeros(nj) 
hess_lag = zeros(nh)

# objective 
MOI.eval_objective(solver.nlp, z)
MOI.eval_objective_gradient(solver.nlp, obj_grad, z)

# constraints 
MOI.eval_constraint(solver.nlp, con, z)
MOI.eval_constraint_jacobian(solver.nlp, con_jac, z)
solver.nlp.hessian_lagrangian && MOI.eval_hessian_lagrangian(solver.nlp, hess_lag, z, 1.0, y)

"""
KKT system

H = [
        ∇²L C' 
        C   0
    ]

h = [
        ∇L 
        c
    ]
"""

C = spzeros(ny, nz) 
H = spzeros(nz + ny, nz + ny)
h = zeros(nz + ny) 

# C 
for (i, idx) in enumerate(solver.nlp.jacobian_sparsity)
    C[idx...] = con_jac[i]
end

# ∇L 
for i = 1:nz
    # objective gradient
    h[i] += obj_grad[i] 

    # C' y 
    cy = 0.0 
    for j = 1:ny 
        # cy += C[j, i] * y[j] 
        if (j, i) in solver.nlp.jacobian_sparsity
            cy += C[j, i] * y[j]
        end
    end
    h[i] += cy
end

# c 
for j = 1:ny 
    h[nz + j] += con[j]
end

#TODO: only fill in half?
# ∇²L
for (i, idx) in enumerate(solver.nlp.hessian_lagrangian_sparsity)
    H[idx...] = hess_lag[i] 
end

for (i, idx) in enumerate(solver.nlp.jacobian_sparsity)
    # C 
    H[nz + idx[1], idx[2]] = con_jac[i] 
    # C' 
    H[idx[2], nz + idx[1]] = con_jac[i]
end

# regularization 
primal_reg = 1.0e-5 
for i = 1:nz 
    H[i, i] += primal_reg 
end

dual_reg = 1.0e-5
for j = 1:ny 
    H[nz + j, nz + j] -= dual_reg 
end

H_dense = Array(H)
eigen(H_dense)
cond(H_dense)
rank(H_dense)

using QDLDL

F = qdldl(H)
sol = zeros(nz + ny)
sol = copy(h)
QDLDL.solve!(F, sol)
norm(sol - (H \ h), Inf)

## solver 
idx = IndicesOptimization(
    nw, nw,
    [collect(1:0), collect(1:0)], [collect(1:0), collect(1:0)],
    Vector{Vector{Vector{Int}}}(), Vector{Vector{Vector{Int}}}(),
    collect(1:nw),
    collect(1:0),
    Vector{Int}(),
    Vector{Vector{Int}}(),
    collect(1:0),
)


ip = interior_point(w0, θ0;
    s = RoboDojo.Euclidean(length(w0)),
    idx = idx,
    r! = r_func, rz! = rw_func_reg, rθ! = rθ_func,
    r  = zeros(idx.nΔ),
    rz = zeros(idx.nΔ, idx.nΔ),
    rθ = zeros(idx.nΔ, length(θ0)),
    opts = RoboDojo.InteriorPointOptions(
            undercut=Inf,
            γ_reg=0.1,
            r_tol=1e-6,
            κ_tol=1e-6,  
            max_ls=25,
            ϵ_min=0.25,
            diff_sol=true,
            verbose=true))

RoboDojo.interior_point_solve!(ip)