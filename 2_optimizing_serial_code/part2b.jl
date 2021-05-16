#=
The Stack and the Heap
Locally, the stack is composed of a stack and a heap. The stack requires a static allocation: it is ordered. Because it's ordered, it is very clear where things are in the stack, and therefore accesses are very quick (think instantanious). However, because this is static, it requires that the size of the variables is known at compile time (to determine all of the variable locations). Since that is not possible with all variables, there exists the heap. The heap is essentially a stack of pointers to objects in memory. When heap variables are needed, their values are pulled up the cache chain and accessed.

Heap allocations are costly because they involve this pointer indirection, so stack allocation should be done when sensible (it's not helpful for really large arrays, but for small values like scalars it's essential!)
=#

using BenchmarkTools

A = rand(100,100)
B = rand(100,100)
C = rand(100,100)

function inner_alloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = [ A[i,j] + B[i,j] ]
        C[i,j] = val[1]
    end
end

println("Testing time performance of inner_alloc")
@btime inner_alloc!(C,A,B)

function inner_noalloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = A[i,j] + B[i,j]
        C[i,j] = val
    end
end

println("Testing time performance of inner_noalloc")
@btime inner_noalloc!(C,A,B)

#=
Why does the array here get heap-allocated? It isn't able to prove/guerentee at compile-time that the array's size will always be a given value, and thus it allocates it to the heap. @btime tells us this allocation occured and shows us the total heap memory that was taken. Meanwhile, the size of a Float64 number is known at compile-time (64-bits), and so this is stored onto the stack and given a specific location that the compiler will be able to directly address.

Note that one can use the StaticArrays.jl library to get statically-sized arrays and thus arrays which are stack-allocated:
=#

using StaticArrays

function static_inner_alloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = @SVector [A[i,j] + B[i,j]]
        C[i,j] = val[1]
    end
end

@btime static_inner_alloc!(C,A,B)