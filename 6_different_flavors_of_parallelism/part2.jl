#=
Multithreading
- Remember that multithreading has an overhead cost of 50-100ns.
- Overlapping computations can re-use the same heap-based caches, meaning that care needs to be taken with how one writes into a dynamically-allocated array.

A simple example that demonstrates this is. First, let's make sure we have multithreading enabled:

Here, values are being read while other threads are writing, meaning that they see a lower value than when they are attempting to write into it. The result is that the total summation is lower than the true value because of this clashing. We can prevent this by only allowing one thread to utilize the heap-allocated variable at a time.
=#

using Base.Threads
Threads.nthreads()

using BenchmarkTools

acc = 0
@threads for i in 1:10000
    global acc
    acc += 1
end
acc

#=
Way 1: Use atomics
When an atomic add is being done, all other threads wishing to do the same computation are blocked. This of course can have a massive effect on performance since atomic computations are not parallel.
=#
acc = Threads.Atomic{Int}(0)
@threads for i in 1:10_000
    atomic_add!(acc,1)
end
acc

#=
Way 2: Using locks
There are two types: SpinLock and reentrant.
SpinLock is non-reentrent, i.e. it will block itself if a thread that calls a lock does another lock. Therefore it has to be used with caution (every lock goes with one unlock), but it's fast. ReentrantLock alleviates those concerns, but trades off a bit of performance.

- SpinLock should only be used around code that takes little time to execute and does not block.
=#

const acc_lock = Ref{Int64}(0)

const spinlock = SpinLock()
function add_spinlock()
    @threads for i in 1:10_000
        lock(spinlock)
        acc_lock[] += 1
        unlock(spinlock)
    end
    acc_lock
end

const reentrantlock = ReentrantLock()
function add_reentrantlock()
    @threads for i in 1:10_000
        lock(reentrantlock)
        acc_lock[] += 1
        unlock(reentrantlock)
    end
    acc_lock
end

acc2 = Atomic{Int64}(0)
function add_atomic()
    @threads for i in 1:10_000
        atomic_add!(acc2, 1)
    end
    acc2
end

function add_singlethread()
    for i in 1:10_000
        acc_lock[] += 1
    end
    acc_lock
end


acc_lock[] = 0
@btime add_spinlock()

acc_lock[] = 0
@btime add_reentrantlock()

@btime add_atomic()

acc_lock[] = 0
@btime add_singlethread()

#=
Note that serial code is the fastest. Why is this so fast? Check the code:
=#

acc_lock[] = 0
@code_llvm add_singlethread()

#=
It just knows to add 10000. So to get a proper timing let's make the size mutable:
=#

const len = Ref{Int64}(10_000)

function add_st_mutable_len()
    for i in 1:len[]
        acc_lock[] += 1
    end
    acc_lock
end

acc_lock[] = 0
add_st_mutable_len()

@btime add_st_mutable_len()

# still super fast. 
# insteading of using a const, let's use a non-constant length

len_non_constant = 10000
function add_st_non_constant_len()
    len::Int64 = len_non_constant
    for i in 1:len
        acc_lock[] += 1
    end
    acc_lock
end

acc_lock[] = 0
add_st_non_constant_len()

@btime add_st_non_constant_len()

#=
It is still fast. Note how we enable type inference by `len::Int64` even on a non-constant value
=#