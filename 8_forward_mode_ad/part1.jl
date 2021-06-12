struct Dual{T}
    val::T
    der::T
end

Base.:+(a::Dual, b::Dual) = Dual(a.val + b.val, a.der + b.der)
Base.:+(a::Dual, b::Number) = Dual(a.val + b, a.der)
Base.:+(b::Number, a::Dual) = a + b

Base.:-(a::Dual, b::Dual) = Dual(a.val - b.val, a.der - b.der)
Base.:-(a::Dual, b::Number) = a + -b
Base.:-(b::Number, a::Dual) = -1 * (a - b)

Base.:*(a::Dual, b::Dual) = Dual(a.val * b.val, a.der * b.val + b.der * a.val)
Base.:*(a::Dual, b::Number) = Dual(a.val * b, a.der * b)
Base.:*(b::Number, a::Dual) = a * b

Base.:/(a::Dual, b::Dual) = Dual(a.val / b.val, (a.der * b.val - b.der * a.val)/(b.val^2))
Base.:/(a::Dual, b::Number) = a * inv(b)
Base.:/(b::Number, a::Dual) = Dual(b / a.val, (-b * a.der) / (a.val ^ 2))

Base.:^(a::Dual, b::Integer) = Base.power_by_squaring(a,b)

f = Dual(3,4)
g = Dual(5,6)

f+g

f*(g+g)

#=
It seems like we may have introduced significant computational overhead by creating a new data structure, and associated methods. Let's see how the performance is:
=#

add(a1,a2,b1,b2) = (a1+b1,a2+b2)

using BenchmarkTools
a,b,c,d = 1053,6424,3464,1345

#=
Ref{T}: An object that safely references data of type T. This type is guaranteed to point to valid, Julia-allocated memory of the correct type. The underlying data is protected from freeing by the garbage collector as long as the Ref itself is referenced.

In Julia, Ref objects are dereferenced (loaded or stored) with [].
=#
@btime add($(Ref(a))[], $(Ref(b))[], $(Ref(c))[], $(Ref(d))[])

f = Dual(1053, 6424)
g = Dual(3464, 1345)
add(j1,j2) = j1+j2
@btime add($(Ref(f))[], $(Ref(g))[])

# Both the performances are comparable. Now let's look at the native code:

@code_native add(a,b,c,d)
@code_native add(f,g)

#=
Defining higher order primitives
We can also define functions of `Dual` objects, using the chain rule. To speed up our derivative function, we can directly hardcode the derivative of known functions which we call _primitives_.
=#

import Base: exp
exp(a::Dual) = Dual(exp(a.val), exp(a.val) * a.der)

f = Dual(2, 3)
exp(f)

#=
Differentiating arbitrary functions
For functions where we don't have a rule, we can recursively do dual number arithmetic within the function until we hit primitives where we know the derivative, and then use the chain rule to propagate the information back up.

Under this algebra, we can represent a+ϵ as Dual(a, 1). Thus, applying f to Dual(a, 1) should give Dual(f(a), f'(a)).

This is thus a 2-dimensional number for calculating the derivative without floating point error, using the compiler to transform our equations into dual number arithmetic.
=#

h(x) = x^2 + 2
a = 3
x_dual = Dual(a,1)
# first component is h(a), second component is h'(a)
h(x_dual)

# we can write a function to get the derivative:
derivative(f,x) = f(Dual(x, one(x))).der

derivative(x -> x^2 + 2, 3)
derivative(x -> x*(x+1) - 2x^2, 0.5)

# As a bigger example, we can take a pure Julia `sqrt` function and differentiate it by changing the internal algebra:
function newton(x)
    a = x
    for i in 1:5
        a = 0.5 * (a + x/a)
    end
    a
end

newton(2)
newton(Dual(2.0,1.0))

#=
Higher dimensions
=#