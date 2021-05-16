#=
The basics of most scientific models are dynamical systems.
A discrete dynamical system is a system which updates through discrete updates:
    state(t+1) = function(state(t), t)

In any case where a continuous model is discretized to loop on the computer, the resulting algorithm is a discrete dynamical system and thus evolves according to its properties.
=#


#= One question we can ask is: is the function below fast?
For it to be fast we need: type stability, auto-specialization on input types, inlining functions
=#
"""
`solve_system(f,u0,p,n)`
Solves the dynamical system:
``u_{n+1} = f(u_n)``
for `n` steps. 
Returns the solution at step `n` for parameter `p`
"""
function solve_system(f, u0, p, n)
    u = u0
    for i in 1:n-1
        u = f(u,p)
    end
    u
end

# Note that the function f is its own type: typeof(f) gives the output `typeof(f)`
# It displays typeof(f) to indicate that the function f is its own type, and thus at automatic specialization time the compiler knows all of the information about the function and thus inlines and performs inference correctly.

f(u,p) = u^2 - p*u
typeof(f)

#=
Analytic analysis of the solutions:
For steady state we have:
u = u^2 - p*u => u = 0 or (p+1)
Now let's look at the norm of the derivative at these points:
    u' = 2u - p
    Thus at the two points we have:
    norm(u'(0)) = norm(p) and 
    norm(u'(p+1)) = norm(p+2)
=#

# guess the output state for these input values
solve_system(f, 1.0, 0.25, 1000)

solve_system(f, 1.2, 0.25, 1000)

# This is another fixed point (p+1) which is fixed but not stable. This means that if you start here, you will always remain here. But as soon as you deviate, you won't come back to it
solve_system(f, 1.25, 0.25, 1000)

solve_system(f, 1.251, 0.25, 20)

# Notice that the moment we go above the steady state `p+1`, we exponentially grow to infinity

# It's funny solve_system(f, 1.251, 0.25, 20) gives Inf but solve_system(f, 1.3, 0.25, 20) gives NaN

solve_system(f, 1.3, 0.25, 20)

solve_system(f, 1.2499999999, 0.25, 1000)
solve_system(f, 1.25, 0.25, 1000)

# Multidimensional System Implementations
"""
lorenz is a discrete system for 3D vector and 4D parameter
"""
function lorenz(u,p)
    α, σ, ρ, β = p
    du1 = u[1] + α*(σ*(u[2]-u[1]))
    du2 = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
    du3 = u[3] + α*(u[1]*u[2] - β*u[3])
    [du1, du2, du3]
end

p = (0.02,10.0,28.0,8/3)
solve_system(lorenz, [1.0,0.0,0.0], p, 1000)

# Let's save the intermediate results as well because the output doesn't make much sense on its own

function solve_system_save(f, u0, p, n)
    u = Vector{typeof(u0)}(undef, n)
    u[1] = u0
    for i in 1:n-1
        u[i+1] = f(u[i],p)
    end
    u
end

to_plot = solve_system_save(lorenz, [1.0,0.0,0.0], p, 1000)

using Plots

x = [to_plot[i][1] for i in 1:length(to_plot)]
y = [to_plot[i][2] for i in 1:length(to_plot)]
z = [to_plot[i][3] for i in 1:length(to_plot)]

plot(x,y,z)
