#=
Function barriers
Since functions automatically specialize on their input types in Julia, we can use this to our advantage in order to make an inner loop fully inferred.
=#
using BenchmarkTools

f(x,y) = x+y

function slow(x)
    a = 4
    b = 2
    for i in 1:100
        c = f(x[1],a)
        d = f(b,c)
        a = f(d, x[2])
    end
    a
end

x = Number[1.0,2.0]
@btime slow(x)

fast(x) = _fast(x[1],x[2])
function _fast(x,y)
    a = 4
    b = 2
    for i in 1:100
        c = f(x,a)
        d = f(b,c)
        a = f(d,y)
    end
    a
end

@btime fast(x)

#=
Notice that the algorithm still doesn't infer since the output of `_fast` isn't inferred. 
But while it's in `_fast` it will have specialized on the fact that `x` is a `Float64` while `a` is an `Int`, making that inner loop fast.
=#

@code_warntype fast(x)

#=
In fact, it will only need to pay one dynamic dispatch, i.e. a multiple dispatch determination that happens at runtime. Notice that whenever functions are inferred, the dispatching is static since the choice of the dispatch is already made and compiled into the LLVM IR.
=#

#=
Specialization at compile time
Julia code will specialize at compile time if it can prove something about the result. For example:
=#

function if_else_function(x)
    y = x isa Int ? 2 : 4.0
    x+y
end

@code_llvm(if_else_function(2))
@code_llvm(if_else_function(2.0))

x = 2
@code_llvm(if_else_function(x))

#=
You might think this function has a branch, but in reality Julia can determine whether `x` is an `Int` or not at compile time, so it will actually compile it away and just turn it into the function `x+2` or `x+4.0`:
=#

#=
Global variables are slow
=#
A = rand(100,100)
B = rand(100,100)
C = rand(100,100)

@btime for j in 1:100, i in 1:100
    C[i,j] = A[i,j] + B[i,j]
end

function addition(C,A,B)
    for j in 1:100, i in 1:100
        C[i,j] = A[i,j] + B[i,j]
    end
    C
end

@btime addition(C,A,B)

#=
if else conditionals are very expensive because of branch prediction
function calls are expensive (read about inlining) @inline
=#

muladd

# also check out MulAddMacro.jl