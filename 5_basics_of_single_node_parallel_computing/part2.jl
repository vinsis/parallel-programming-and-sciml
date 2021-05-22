#=
Multi-threading:
If your threads are independent, then it may make sense to run them in parallel. This is the form of parallelism known as multithreading.

Each thread has its own call stack, but it's the process that holds the heap. This means that dynamically-sized heap allocated objects are shared between threads with NO COST, a setup known as shared-memory computing.
=#

# Let's look back at our Lorenz dynamical system from before:

using StaticArrays, BenchmarkTools

function lorenz(u,p)
    α,σ,ρ,β = p
    @inbounds begin
      du1 = u[1] + α*(σ*(u[2]-u[1]))
      du2 = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
      du3 = u[3] + α*(u[1]*u[2] - β*u[3])
    end
    @SVector [du1,du2,du3]
end

function solve_system_save!(u,f,u0,p,n)
    @inbounds u[1] = u0
    @inbounds for i in 1:length(u)-1
      u[i+1] = f(u[i],p)
    end
    u
end

p = (0.02,10.0,28.0,8/3)
u = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef, 1000)
@btime solve_system_save!(u, lorenz, @SVector([1.0,0.0,0.0]), p, 1000)

#=
In order to use multithreading on this code, we need to take a look at the dependency graph and see what items can be calculated independently of each other. 
There are two ways we can do this:
1. Calculate the following independently (4 threads):
```
σ*(u[2]-u[1])
ρ-u[3]
u[1]*u[2]
β*u[3]
```

2. Calculate the following independently (3 threads):
```
u[1] + α*(σ*(u[2]-u[1]))
u[2] + α*(u[1]*(ρ-u[3]) - u[2])
u[3] + α*(u[1]*u[2] - β*u[3])
```

We can do this by using Julia's `Threads.@threads` macro which puts each of the computations of a loop in a different thread. 

The threaded loops do not allow you to return a value, so how do you build up the values for the `@SVector`.

There is a shared heap, but the stacks are thread local. This means that a value cannot be stack allocated in one thread and magically appear when re-entering the main thread: it needs to go on the heap somewhere. But if it needs to go onto the heap, then it makes sense for us to have preallocated its location. But if we want to preallocate du[1], du[2], and du[3], then it makes sense to use the fully non-allocating update form:
=#

function lorenz!(du,u,p)
    α,σ,ρ,β = p
    @inbounds begin
      du[1] = u[1] + α*(σ*(u[2]-u[1]))
      du[2] = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
      du[3] = u[3] + α*(u[1]*u[2] - β*u[3])
    end
end

function solve_system_save_iip!(u,f,u0,p,n)
    @inbounds u[1] = u0
    @inbounds for i in 1:length(u)-1
      f(u[i+1],u[i],p)
    end
    u
end

p = (0.02,10.0,28.0,8/3)
# u lives on the heap
u = [Vector{Float64}(undef,3) for i in 1:1000]

@btime solve_system_save_iip!(u,lorenz!,[1.0,0.0,0.0],p,1000)

# and now we multi-thread. A quick note about `let`:
# let statements allocate new variable bindings each time they run. it makes sense to write something like `let x = x` since the two `x` variables are distinct and have separate storage.

using Base.Threads

function lorenz_mt!(du,u,p)
    α,σ,ρ,β = p
    let du=du, u=u, p=p
        Threads.@threads for i in 1:3
            @inbounds begin
                if i==1
                    du[1] = u[1] + α*(σ*(u[2]-u[1]))
                elseif i==2
                    du[2] = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
                else
                    du[3] = u[3] + α*(u[1]*u[2] - β*u[3])
                end
                nothing
            end
        end
    end
    nothing
end

function solve_system_save_iip!(u,f,u0,p,n)
    @inbounds u[1] = u0
    @inbounds for i in 1:length(u)-1
      f(u[i+1],u[i],p)
    end
    u
end

p = (0.02,10.0,28.0,8/3)
u = [Vector{Float64}(undef,3) for i in 1:1000]
@btime solve_system_save_iip!(u,lorenz_mt!,[1.0,0.0,0.0],p,1000);

#=
Parallelism doesn't always make things faster. There are two costs associated with this code. For one, we had to go to the slower heap+mutation version, so its implementation starting point is slower. But secondly, and more importantly, the cost of spinning a new thread is non-negligable.
=#

#=
Data-Parallel Problems
Dynamical systems cannot be parallelized when calculating through time. But they can be parallelized for two scenarios:
1. What steady state does an input `u0` go to for some list/region of initial conditions?
2. How does the solution vary when I use a different `p`?

Multithreaded Parameter Searches
Let's say we wanted to compute the mean of the values in the trajectory. For a single input pair, we can compute that like:
=#

# function lorenz(u,p)
#     α,σ,ρ,β = p
#     @inbounds begin
#       du1 = u[1] + α*(σ*(u[2]-u[1]))
#       du2 = u[2] + α*(u[1]*(ρ-u[3]) - u[2])
#       du3 = u[3] + α*(u[1]*u[2] - β*u[3])
#     end
#     @SVector [du1,du2,du3]
# end

# function solve_system_save!(u,f,u0,p,n)
#     @inbounds u[1] = u0
#     @inbounds for i in 1:length(u)-1
#       u[i+1] = f(u[i],p)
#     end
#     u
# end

using Statistics
function compute_trajectory_mean(u0,p)
  u = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000)
  solve_system_save!(u,lorenz,u0,p,1000);
  mean(u)
end
@btime compute_trajectory_mean(@SVector([1.0,0.0,0.0]),p)

#=
We can make this faster by preallocating the cache vector u. For example, we can globalize it:
=#

u = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000)
function compute_trajectory_mean2(u0,p)
  # u is automatically captured
  solve_system_save!(u,lorenz,u0,p,1000);
  mean(u)
end
@btime compute_trajectory_mean2(@SVector([1.0,0.0,0.0]),p)

#=
But this is still allocating? The issue with this code is that u is a global, and captured globals cannot be inferred because their type can change at any time. Thus what we can do instead is capture a constant:
=#

const _u_cache = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000)
function compute_trajectory_mean3(u0,p)
  # u is automatically captured
  solve_system_save!(_u_cache,lorenz,u0,p,1000);
  mean(_u_cache)
end
@btime compute_trajectory_mean3(@SVector([1.0,0.0,0.0]),p)

#=
The other way to do this is to use a closure which encapsulates the cache data:
=#

function _compute_trajectory_mean4(u,u0,p)
    solve_system_save!(u,lorenz,u0,p,1000);
    mean(u)
end

compute_trajectory_mean4(u0,p) = _compute_trajectory_mean4(_u_cache,u0,p)
@btime compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p)

#=
This is the same, but a bit more explicit.
=#

#=
Now let's create our parameter search function. Let's take a sample of parameters. And let's get the mean of the trajectory for each of the parameters.
=#

ps = [(0.02,10.0,28.0,8/3) .* (1.0,rand(3)...) for i in 1:1000]

serial_out = map(p -> compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p),ps)

# Now let's do this with multithreading:
function tmap(f,ps)
    out = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000)
    Threads.@threads for i in 1:1000
        out[i] = f(ps[i])
    end
    out
end

threaded_out = tmap(p -> compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p),ps)

# Let's check the output:
serial_out - threaded_out
