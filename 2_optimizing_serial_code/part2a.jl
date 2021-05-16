#= Cache lines and column major order
Many algorithms in numerical linear algebra are designed to minimize cache misses. Because of this chain, many modern CPUs try to guess what you will want next in your cache. When dealing with arrays, it will speculate ahead and grab what is known as a cache line: the next chunk in the array. Thus, your algorithms will be faster if you iterate along the values that it is grabbing.
=#

using BenchmarkTools

A = rand(100,100);
B = rand(100,100);
C = rand(100,100);


function inner_cols!(C,A,B)
    for row in 1:100, col in 1:100
        C[row, col] = A[row, col] + B[row, col]
    end
end

println("Measuring time for row major order (change outer dim first)")
@btime inner_cols!(C,A,B)

function inner_rows!(C,A,B)
    for col in 1:100, row in 1:100
        C[row, col] = A[row, col] + B[row, col]
    end
end

println("Measuring time for col major order (change inner dim first)")
@btime inner_rows!(C,A,B)