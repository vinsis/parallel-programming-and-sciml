using BenchmarkTools

function lorenz(u,p)
    α, σ, ρ, β = p
    du1 = u[1] + α*(σ*(u[2]-u[1]))
    du2 = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
    du3 = u[3] + α*(u[1]*u[2] - β*u[3])
    [du1, du2, du3]
end

# We will look at different ways to implement the `solve_system_*` and how to make all of them fast

function solve_system_save(f, u0, p, n)
    u = Vector{typeof(u0)}(undef, n)
    u[1] = u0
    for i in 1:n-1
        u[i+1] = f(u[i],p)
    end
    u
end

u0 = [1.0,0.0,0.0]
p = (0.02,10.0,28.0,8/3)

@btime solve_system_save(lorenz, u0, p, 1000)

#=
`u = Vector{typeof(u0)}(undef,n)` is type-generic, meaning any `u0` can be used with that code. However, as a vector of vectors, it is a vector of pointers to contiguous memory, instead of being contiguous itself. This means there is not much of a cost by not pre-specifying the size up front like so `u = Vector{typeof(u0)}(undef, n)`

This is because growth costs are amortized, meaning that when pushing, the size isn't increasing by one each time, but rather it's doing something like doubling, so that it's averaging O(1) cost to keep growing
=#

function solve_system_save_push(f, u0, p, n)
    u = Vector{typeof(u0)}(undef,1)
    u[1] = u0
    for i in 1:n-1
        push!(u, f(u[i],p))
    end
    u
end

@btime solve_system_save_push(lorenz, u0, p, 1000)

# Let's use Matrices
function solve_system_save_matrix(f, u0, p, n)
    M = Matrix{eltype(u0)}(undef, length(u0), n)
    M[:,1] = u0
    for i in 1:n-1
        M[:, i+1] = f(M[:,i], p)
    end
    M
end

@btime solve_system_save_matrix(lorenz, u0, p, 1000)

#=
Now it takes twice as long as the number of allocations has also doubled. 

Where is this cost coming from? A large portion of the cost is due to the slicing on the u, which we can fix with a `view`:
=#

function solve_system_save_matrix_view(f, u0, p, n)
    M = Matrix{eltype(u0)}(undef, length(u0), n)
    M[:,1] = u0
    for i in 1:n-1
        M[:,i+1] = f(@view(M[:,i]),p)
    end
    M
end

@btime solve_system_save_matrix_view(lorenz, u0, p, 1000)

#=
Growing the matrix adaptively is not a very good idea since every growth requires both allocating memory and copying over the old values
=#

function solve_system_save_matrix_resize(f, u0, p, n)
    M = Matrix{eltype(u0)}(undef, length(u0), 1)
    M[:,1] = u0
    for i in 1:n-1
        M = hcat(M, f(@view(M[:,i]), p))
    end
    M
end

@btime solve_system_save_matrix_resize(lorenz, u0, p, 1000)

#=
Also since we are only ever using single columns as a unit, notice that there isn't any benefit to keeping the whole thing contiguous, and in fact there are some downsides (cache is harder to optimize because the longer cache lines are unnecessary, the views need to be used).

So for now let's go back to the Vector of Arrays approach. One way to reduce the number of allocations is to require that the user provides an in-place non-allocating function:
=#

function lorenz!(du,u,p)
    α,σ,ρ,β = p
    du[1] = u[1] + α*(σ*(u[2]-u[1]))
    du[2] = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
    du[3] = u[3] + α*(u[1]*u[2] - β*u[3])
end

p = (0.02,10.0,28.0,8/3)

function solve_system_save_v2(f, u0, p, n)
    u = Vector{typeof(u0)}(undef, n)
    du = similar(u0)
    u[1] = u0
    for i in 1:n-1
        f(du,u[i],p)
        u[i+1] = du
    end
    u
end

solve_system_save_v2(lorenz!, u0, p, 1000)

#=
Oh no, all of the outputs are the same! What happened? The problem is in the line u[i+1] = du. What we had done is set the save vector to the same pointer as du, effectively linking all of the pointers.

We could use `u[i+1] = copy(du)` but that nullifies the advantage of the non-allocating approach. 

However, if only the end point is necessary, then the reduced allocation approach is helpful:
=#

function solve_system_mutate(f, u0, p, n)
    du = similar(u0)
    u = copy(u0)
    for i in 1:n-1
        f(du,u,p)
        u,du = du,u
    end
    u
end

solve_system_mutate(lorenz!, u0, p, 1000)
@btime solve_system_mutate(lorenz!, u0, p, 1000)

#=
An alternative way to write the inner loop is:
`for i in 1:n-1
  f(du,u,p)
  u .= du
end`
which would compute f and then take the values of du and update u with them, but that's 3 extra operations than required, whereas u,du = du,u will change u to be a pointer to the updated memory and now du is an "empty" cache array that we can refill (this decreases the computational cost by ~33%). Let's see what the cost is with this newest version:
=#