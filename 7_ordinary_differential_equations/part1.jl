#=
Let's solve some popular differential equations from various fields
=#

# Lorenz equations
using DifferentialEquations
using Plots

function lorenz(du,u,p,t)
    du[1] = p[1]*(u[2]-u[1])
    du[2] = u[1]*(p[2]-u[3]) - u[2]
    du[3] = u[1]*u[2] - p[3]*u[3]
end

u0 = [1.0,0.0,0.0]
tspan = (0.0,100.0)
p = (10.0,28.0,8/3)

prob = ODEProblem(lorenz,u0,tspan,p)
sol = solve(prob)

plot(sol)
plot(sol, vars=(1,2,3))

# index 0 corresponds to t. So you can plot (t,y,z) like so:
plot(sol, vars=(0,2,3))

# state at discrete time steps
sol[1]
sol[2]
# state at any time t
sol(1.5)

#=
N-body problems and astronomy: Let's solve Pleiades problem, an approximation to seven star chaotic system.
=#

function pleiades(du,u,p,t)
    @inbounds begin
        x = view(u,1:7)
        y = view(u,8:14)
        v = view(u,15:21)
        w = view(u,22:28)
        du[1:7] .= v
        du[8:14] .= w
        for i in 15:28
            du[i] = zero(u[1])
        end
        for i=1:7,j=1:7
            if i != j
                r = ((x[i]-x[j])^2 + (y[i] - y[j])^2)^(3/2)
                du[14+i] += j*(x[j] - x[i])/r
                du[21+i] += j*(y[j] - y[i])/r
            end
        end
    end
end

tspan = (0.0,3.0)
initial_condition_pleiades = [3.0,3.0,-1.0,-3.0,2.0,-2.0,2.0,3.0,-3.0,2.0,0,0,-4.0,4.0,0,0,0,0,0,1.75,-1.5,0,0,0,-1.25,1,0,0]
prob = ODEProblem(pleiades,initial_condition_pleiades,tspan)

sol = solve(prob, Vern8(), abstol=1e-10, reltol=1e-10)

plot(sol)

tspan = (0.0,200.0)
prob = ODEProblem(pleiades, initial_condition_pleiades, tspan)
sol = solve(prob, Vern8(), abstol=1e-10, reltol=1e-10)
sol(5.5)

plot(sol, vars=((1:7),(8:14)))

#=
Population ecology: Lotka-Volterra equations
=#

function lotka(du,u,p,t)
    du[1] = p[1]*u[1] - p[2]*u[1]*u[2]
    du[2] = -p[3]*u[2] + p[4]*u[1]*u[2]
end

p = [1.5,1.0,3.0,1.0]
prob = ODEProblem(lotka,[1.0,1.0],(0.0,10.0),p)
sol = solve(prob)
plot(sol)
