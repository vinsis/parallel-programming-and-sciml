#=
Mutation to Avoid Heap Allocations
Many times you do need to write into an array, so how can you write into an array without performing a heap allocation? The answer is mutation. Mutation is changing the values of an already existing array. In that case, no free memory has to be found to put the array (and no memory has to be freed by the garbage collector).
=#

using BenchmarkTools

A = rand(100,100)
B = rand(100,100)
C = rand(100,100)

function inner_noalloc!(C,A,B)
    for j in 1:100, i in 1:100
        C[i,j] = A[i,j] + B[i,j]
    end
end

println("Testing time performance of inner_noalloc")
@btime inner_noalloc!(C,A,B)

function inner_alloc(A,B)
    C = similar(A)
    for j in 1:100, i in 1:100
        C[i,j] = A[i,j] + B[i,j]
    end
end

println("Testing time performance of inner_alloc")
@btime inner_alloc(A,B)

#=
To use this algorithm effectively, the ! algorithm assumes that the caller already has allocated the output array to put as the output argument. If that is not true, then one would need to manually allocate. The goal of that interface is to give the caller control over the allocations to allow them to manually reduce the total number of heap allocations and thus increase the speed.
=#