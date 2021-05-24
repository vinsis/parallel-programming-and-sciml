using BenchmarkTools

#=
There can be major differences in computing using a struct of array format instead of an arrays of structs format. For example `array` in stored in memory as [real1,imag1,real2,imag2,...]
=#

struct MyComplex
    real::Float64
    imag::Float64
end

array = [MyComplex(rand(), rand()) for i in 1:1000]

#=
while the following as [real1, real2, ..., imag1, imag2, ...]
=#
struct MyComplexes
    real::Vector{Float64}
    imag::Vector{Float64}
end

array2 = MyComplexes(rand(100), rand(100))

Base.:+(x::MyComplex, y::MyComplex) = MyComplex(x.real+y.real, x.imag+y.imag)
Base.:/(x::MyComplex, y::Int) = MyComplex(x.real/y, x.imag/y)
average(x::Vector{MyComplex}) = sum(x)/length(x)

#What this is doing is creating small little vectors and then parallelizing the operations of those vectors by calling specific vector-parallel instructions. Keep this in mind.
@code_llvm average(array)

@btime average(array)

average(x::MyComplexes) = MyComplex(sum(x.real)/length(x.real), sum(x.imag)/length(x.imag))

@btime average(array2)

@code_llvm average(array2)

# let's look at code native
@code_native average(array)
@code_native average(array2)

#=
Broadcasting (.*, .+ etc) and reductions (sum, minimum etc) automatically use SIMD in Julia
=#

#=
- Sum of integers uses SIMD 
- Addition on floating point numbers is not associative and summing them up doesn't use SIMD. To use SIMD, use @simd
=#
floats = [rand() for i in 1:1000]

function mysum(x::Vector{eltype(floats)})
    out = 0.0
    @inbounds for i in 1:1000
        out += x[i]
    end
    out
end

function mysum_simd(x::Vector{eltype(floats)})
    out = 0.0
    @inbounds @simd for i in 1:1000
        out += x[i]
    end
    out
end

# Each of these operations gives different results
#=
`sum` uses pairwise summation by default which gives better accuracy and the same speed as regular.
=#
mysum(floats)
mysum_simd(floats)
sum(floats)

