#=
The Basics of Single Node Parallel Computing
Concurrency vs parallelism
Each thread has its own stack and vCPU
Heap is shared among threads
A process is a discrete unit with a heap, many threads, allocated memory etc
=#

#=
Concurrency
=#

# takes 2 seconds
@time sleep(2)

# takes 20 seconds
@time for i in 1:10
    sleep(2)
end

# takes an instant
# spawns different threads to execute tasks and doesn't wait for them to finish
@time for i in 1:10
    @async sleep(2)
end

# takes 2 seconds 
# wait for all of the concurrent tasks to finish
@time @sync for i in 1:10
    @async sleep(2)
end

# the inner time takes an instant, outer 2 seconds
@time @sync @time for i in 1:10
    @async sleep(2)
end

#=
import Base.Threads.@spawn
@spawn
  Threads.@spawn expr

  Create and run a Task on any available thread. To wait for the task to finish, call wait on the result of this macro, or call
  fetch to wait and then obtain its return value.
=#

import Base.Threads.@spawn

#=
@spawn will spawn a new thread for the for loop in a non-blocking way.
But `fetch` is blocking so it will run only after the above thread has finished running
=#
@time begin
    t = @spawn for i in 1:10
        sleep(1)
    end

    println("Hello")
    fetch(t)
    println("Hello there")
end

#=
Examples of the differences
1. Asynchronous + non-blocking: I/O
2. Asynchronous + blocking: Threaded atomics (in next lecture)
3. Synchronous + blocking: standard computing, @sync
4. Synchronous + non-blocking: web servers where an I/O operation can be performed but one never checks if the operation is completed. This is essentially never used in scientific computing.
=#