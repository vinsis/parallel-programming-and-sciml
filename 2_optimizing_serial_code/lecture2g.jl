#=
In Julia, types which can fully inferred and which are composed of primitive or `isbits` types are value types. This means that, inside of an array, their values are the values of the type itself, and not a pointer to the values.

You can check if the type is a value type through `isbits`:
=#

isbits(5)
isbits((struct A end))
isbits([1,2])
isbitstype(Vector)

#=
Note that a Julia struct which holds `isbits` values is `isbits` as well, if it's fully inferred:
=#

struct MyComplex
    real::Float64
    imag::Float64
end

isbitstype(MyComplex)
isbits(MyComplex(1,1))

# We can see that the compiler knows how to use this efficiently since it knows that what comes out is always `Float64`:

f(x,y) = x+y
function g(x,y)
    a = 2
    b = 4
    c = f(a,x)
    d = f(b,c)
    f(d,y)
end

Base.:+(a::MyComplex, b::MyComplex) = MyComplex(a.real + b.real, a.imag + b.imag)
Base.:+(a::MyComplex, b::Int) = MyComplex(a.real + b, a.imag)
Base.:+(a::Int, b::MyComplex) = MyComplex(b.real + a, b.imag)

@code_warntype g(MyComplex(1.0,1.0), MyComplex(2.0,1.1))

#=
Note that the compiled code simply works directly on the `double` pieces. This is the beauty of SIMD
=#

@code_llvm g(MyComplex(1.0,1.0), MyComplex(2.0,1.1))

#=
Additionally read up on how primitive types are defined like so:
primitive type Float64 64 end

Bio.jl defined A,T,G,C as primitive types in similar manner
=#

struct MyParameterizedComplex{T}
    real::T
    imag::T
end

isbitstype(MyParameterizedComplex)
isbitstype(MyParameterizedComplex{Float64})
isbitstype(MyParameterizedComplex{AbstractFloat})

isbits(MyParameterizedComplex(1.0,1.0))

Base.:+(a::MyParameterizedComplex, b::MyParameterizedComplex) = MyParameterizedComplex(a.real+b.real, a.imag+b.imag)
Base.:+(a::MyParameterizedComplex, b::Int) = MyParameterizedComplex(a.real+b, a.imag)
Base.:+(a::Int, b::MyParameterizedComplex) = MyParameterizedComplex(a+b.real, b.imag)

g(MyParameterizedComplex(1.0,2.0), MyParameterizedComplex(2.0,1.0))

@code_warntype g(MyParameterizedComplex(1.0,2.0), MyParameterizedComplex(2.0,1.0))

using BenchmarkTools

@btime g(MyComplex(1.0,2.0), MyComplex(2.0,1.0))
@btime g(MyParameterizedComplex(1.0,2.0), MyParameterizedComplex(2.0,1.0))

@code_llvm g(MyParameterizedComplex(1.0,2.0), MyParameterizedComplex(2.0,1.0))

@code_llvm g(MyParameterizedComplex(1f0,2f0), MyParameterizedComplex(2f0,1f0))

#=
This will not work as fast: if there is any piece of a type which doesn't contain type information, then it cannot be isbits because then it would have to be compiled in such a way that the size is not known in advance.
=#

struct MySlowComplex
    real
    imag
end

isbits(MySlowComplex(1.0,1.0)) #false since the memory needed cannot be deduced

struct MySlowComplex2
    real::AbstractFloat
    imag::AbstractFloat
end

isbits(MySlowComplex2(1.0,1.0))

Base.:+(a::MySlowComplex, b::MySlowComplex) = MySlowComplex(a.real+b.real, a.imag+b.imag)
Base.:+(a::MySlowComplex, b::Int) = MySlowComplex(a.real+b, a.imag)
Base.:+(a::Int, b::MySlowComplex) = MySlowComplex(a+b.real, b.imag)

Base.:+(a::MySlowComplex2, b::MySlowComplex2) = MySlowComplex2(a.real+b.real, a.imag+b.imag)
Base.:+(a::MySlowComplex2, b::Int) = MySlowComplex2(a.real+b, a.imag)
Base.:+(a::Int, b::MySlowComplex2) = MySlowComplex2(a+b.real, b.imag)

@btime g(MyComplex(1.0,2.0), MyComplex(2.0,1.0))
@btime g(MyParameterizedComplex(1.0,2.0), MyParameterizedComplex(2.0,1.0))
@btime g(MySlowComplex(1.0,2.0), MySlowComplex(2.0,1.0))
@btime g(MySlowComplex2(1.0,2.0), MySlowComplex2(2.0,1.0))

#=
Note how moving the variable definitions outside gives *actual* performance.
When the variable defitions are passed along, the compiler does too much of an optimization.
=#

x,y = MyComplex(1.0,2.0), MyComplex(2.0,1.0)
@btime g(x,y)
x,y = MyParameterizedComplex(1.0,2.0), MyParameterizedComplex(2.0,1.0)
@btime g(x,y)
x,y = MySlowComplex(1.0,2.0), MySlowComplex(2.0,1.0)
@btime g(x,y)
x,y = MySlowComplex2(1.0,2.0), MySlowComplex2(2.0,1.0)
@btime g(x,y) # this is every slower than MySlowComplex. In this case having partial information is worse than not having any information at all

#=
Note that a type which is `mutable struct` will not be isbits.
=#