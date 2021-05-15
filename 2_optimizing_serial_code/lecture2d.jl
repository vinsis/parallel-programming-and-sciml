#=
Julia's Broadcasting Mechanism
`A .+ B .+ C;` under the hood lowers to something like:
`map((a,b,c)->a+b+c,A,B,C);`
=#

using BenchmarkTools

A = rand(100,100)
B = rand(100,100)
C = rand(100,100)

function unfused(A,B,C)
    temp = A .+ B
    return temp .+ C
end
println("Testing time performance of unfused")
@btime unfused(A,B,C);

fused(A,B,C) = A .+ B .+ C
println("Testing time performance of fused")
@btime fused(A,B,C);

#=
Note that we can also fuse the output by using `.=`. This is essentially the vectorized version of a `!` function:
=#

D = similar(A)
fused!(D,A,B,C) = (D .= A .+ B .+ C)

println("Testing time performance of fused!")
@btime fused!(D,A,B,C)

#=
The reason vectorization is recommended is because looping is slow in these languages. Because looping isn't slow in Julia (or C, C++, Fortran, etc.), loops and vectorization generally have the same speed. So use the one that works best for your code without a care about performance.
=#

function vectorized!(D,A,B,C)
    D .= A .+ B .+ C
    D
end

function not_vectorized!(D,A,B,C)
    for i in 1:length(D)
        D[i] = A[i] + B[i] + C[i]
    end
    D
end

function not_vectorized_inbounds!(D,A,B,C)
    @inbounds for i in 1:length(D)
        D[i] = A[i] + B[i] + C[i]
    end
    D
end

println("Checkting time performance of vectorized")
@btime vectorized!(D,A,B,C)

println("Checkting time performance of not_vectorized")
@btime not_vectorized!(D,A,B,C)

println("Checkting time performance of vectorized")
@btime not_vectorized_inbounds!(D,A,B,C)