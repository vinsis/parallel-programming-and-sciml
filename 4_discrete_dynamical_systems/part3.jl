#=
One last change that we could do is make use of StaticArrays. To do this, we need to go back to non-mutating, like:
=#
using StaticArrays

function lorenz(u,p)
    α,σ,ρ,β = p
    du1 = u[1] + α*(σ*(u[2]-u[1]))
    du2 = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
    du3 = u[3] + α*(u[1]*u[2] - β*u[3])
    @SVector [du1,du2,du3]
end

p = (0.02,10.0,28.0,8/3)

function solve_system_save(f, u0, p, n)
    u = Vector{typeof(u0)}(undef, n)
    u[1] = u0
    for i in 1:n-1
        u[i+1] = f(u[i],p)
    end
    u
end

solve_system_save(lorenz, @SVector[1.0,0.0,0.0], p, 1000)
@btime solve_system_save(lorenz, @SVector[1.0,0.0,0.0], p, 1000)

#=
This is so much faster. This is utilizing a lot more optimizations, like SIMD, automatically, which is helpful. Let's also remove the bounds checks:
=#

function lorenz(u,p)
    α,σ,ρ,β = p
    @inbounds begin
      du1 = u[1] + α*(σ*(u[2]-u[1]))
      du2 = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
      du3 = u[3] + α*(u[1]*u[2] - β*u[3])
    end
    @SVector [du1,du2,du3]
end

function solve_system_save(f,u0,p,n)
    u = Vector{typeof(u0)}(undef,n)
    @inbounds u[1] = u0
    @inbounds for i in 1:n-1
        u[i+1] = f(u[i],p)
    end
    u
end

solve_system_save(lorenz,@SVector[1.0,0.0,0.0],p,1000)

@btime solve_system_save(lorenz,@SVector[1.0,0.0,0.0],p,1000)

#=
And we can get down to non-allocating for the loop:
=#

function solve_system(f, u0, p, n)
    u = u0
    for i in 1:n-1
        u = f(u,p)
    end
    u
end



@btime solve_system(lorenz, @SVector([1.0,0.0,0.0]), p, 1000)

# There is only one allocation. Notice that the single allocation is the output.

#=
We can lastly make the saving version completely non-allocating if we hoist the allocation out to the higher level:
=#

function solve_system_save!(u,f,u0,p,n)
    @inbounds u[1] = u0
    @inbounds for i in 1:length(u)-1
        u[i+1] = f(u[i],p)
    end
    u
end

u = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef, 1000)
@btime solve_system_save!(u, lorenz, @SVector([1.0,0.0,0.0]), p, 1000)