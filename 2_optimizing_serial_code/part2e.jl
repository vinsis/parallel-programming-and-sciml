#=
Heap allocations from slicing
Slices in Julia produce copies instead of views.

You should always benchmark things inside of functions. Julia JIT-compiles functions.
=#

using BenchmarkTools

A = rand(100,100)

function f(A)
    A[1:5, 1:5]
end

function g(A)
    @view A[1:5, 1:5]
end

println("Testing time performance of f")
# the amount of allocation here will change depending on the size of slice returned
@btime f(A);

println("Testing time performance of g")
# the amount of allocation is constant
@btime g(A);

newA = f(A);
newA[1,1] = 2.0;
A[1:5, 1:5]

newA = g(A)
newA[1,1] = 2.0
A[1:5, 1:5]

@belapsed f(A)
@belapsed g(A)

#=
Other places where allocation is constant
=#

@btime 1:500
@btime 1:50000000000
@btime 1:5000000000000000000000000000
# for the example below, there are 8 allocations because the `end` is a `BigInt` and allocations are made to store that number
@btime 1:5000000000000000000000000000000000000000000000000000000

propertynames(1:50)
@which (1:50)[4]

#=
Asymptotic cost of heap allocations
Heap allocation is O(n). Thus if the operation involving the object the heap is allocated to is also O(n), then preventing heap allocation is beneficial asymptotically.

However if the operation is > O(n), eg matrix multiplication is O(n^3), the savings from preventing heap allocation matter less and less. This is why ML in Python is fast. 
=#

