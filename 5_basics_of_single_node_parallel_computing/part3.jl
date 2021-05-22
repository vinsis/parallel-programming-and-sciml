println(Threads.nthreads())

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

const _u_cache = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000)

function _compute_trajectory_mean4(u,u0,p)
    solve_system_save!(u,lorenz,u0,p,1000);
    mean(u)
end

compute_trajectory_mean4(u0,p) = _compute_trajectory_mean4(_u_cache,u0,p)
compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p)

ps = [(0.02,10.0,28.0,8/3) .* (1.0,rand(3)...) for i in 1:1000]
serial_out = map(p -> compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p),ps)

@btime map(p -> compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p),ps)

function tmap(f,ps)
    out = Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000)
    Threads.@threads for i in 1:1000
        out[i] = f(ps[i])
    end
    out
end
threaded_out = tmap(p -> compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p),ps)

@btime tmap(p -> compute_trajectory_mean4(@SVector([1.0,0.0,0.0]),p),ps)

serial_out - threaded_out

#=
We don't get the same answer! What happened?

The answer is the caching. Every single thread is using `_u_cache` as the cache, and so while one is writing into it the other is reading out of it, and thus is getting the value written to it from the wrong cache!

To fix this we need a different heap per thread
=#

const _u_cache_threads = [Vector{typeof(@SVector([1.0,0.0,0.0]))}(undef,1000) for i in 1:Threads.nthreads()]
function compute_trajectory_mean5(u0,p)
    # u is automatically captured
    solve_system_save!(_u_cache_threads[Threads.threadid()],lorenz,u0,p,1000);
    mean(_u_cache)
end
@btime compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p)
  
serial_out = map(p -> compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p),ps)
threaded_out = tmap(p -> compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p),ps)
serial_out - threaded_out

@btime serial_out = map(p -> compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p),ps)
@btime threaded_out = tmap(p -> compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p),ps)

#=
Hierarchical Task-Based Multithreading and Dynamic Scheduling
All independent threads are parallelized, and a new interface for multithreading will exist that works by spawning threads.
=#

function tmap2(f,ps)
    tasks = [Threads.@spawn f(ps[i]) for i in 1:length(ps)]
    out = [fetch(t) for t in tasks]
    out
end
threaded_out = tmap2(p -> compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p),ps)


# However, if we check the timing we see:
# 2.207 ms (7004 allocations: 468.97 KiB)
@btime tmap2(p -> compute_trajectory_mean5(@SVector([1.0,0.0,0.0]),p),ps)

#=
The reason is because Threads.@threads employs static scheduling while Threads.@spawn is using dynamic scheduling. Dynamic scheduling is the model of allowing the runtime to determine the ordering and scheduling of processes, i.e. what tasks will run run where and when. Julia's task-based multithreading system has a thread scheduler which will automatically do this for you in the background, but because this is done at runtime it will have overhead. Static scheduling is the model of pre-determining where and when tasks will run, instead of allowing this to be determined at runtime. Threads.@threads is "quasi-static" in the sense that it cuts the loop so that it spawns only as many tasks as there are threads, essentially assigning one thread for even chunks of the input data.

Does this lack of runtime overhead mean that static scheduling is "better"? No, it simply has trade-offs. Static scheduling assumes that the runtime of each block is the same. For this specific case where there are fixed number of loop iterations for the dynamical systems, we know that every compute_trajectory_mean5 costs exactly the same, and thus this will be more efficient. However, There are many cases where this might not be efficient. For example:
=#

function sleepmap_static()
    out = Vector{Int}(undef, 24)
    Threads.@threads for i in 1:24
        sleep(i/10)
        out[i] = i
    end
    out
end

isleep(i) = (sleep(i/10); i)
function sleepmap_spawn()
    tasks = [Threads.@spawn isleep(i) for i in 1:24]
    out = [fetch(t) for t in tasks]
    out
end

@btime sleepmap_static()
@btime sleepmap_spawn()

#=
The reason why this occurs is because of how the static scheduling had chunked the calculation.
The first thread takes `sum(i/10 for i in 1:4)` = 1 second and the last one takes
`sum(i/10 for i in 21:24)` = 9 seconds.

Thus by unevenly distributing the runtime, we run as fast as the slowest thread. However, dynamic scheduling allows new tasks to immediately run when another is finished, meaning that the in that case the shorter tasks tend to be piled together, causing a faster execution. Thus whether dynamic or static scheduling is beneficial is dependent on the problem and the implementation of the static schedule.
=#

# Array based parallelism

#=
The simplest form of parallelism is array-based parallelism. The idea is that you use some construction of an array whose operations are already designed to be parallel under the hood. In Julia, some examples of this are:

- DistributedArrays (Distributed Computing)
- Elemental
- MPIArrays
- CuArrays (GPUs)
=#