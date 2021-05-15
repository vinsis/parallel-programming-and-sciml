#=
llvm creates an IR for the compiler. This IR is platform agnostic, which is then converted into assembly code.
Note how `f(1,2)` and `f(1,2.0)` are converted into different IRs depending on the types involved.

The reason why Julia is fast is because of the combination of two ideas:
1. Type inference
2. Type specialization in functions

a=3
b=2
a+b

The Python interpreter cannot statically guerentee exact unchanging values for the size that a value would take in the stack, meaning that the variables are not stack-allocated. This means that every number ends up heap-allocated.

However, **before JIT compilation**, Julia runs a type inference algorithm which finds out that `A` is an `Int`, and `B` is an `Int`. You can then understand that if it can prove that `A+B` is an `Int`, then it can **propogate** all of the types through.

`f(x,y) = x+y`
In Julia, `f` is not what you may think of as a "single function", since given inputs of different types it will actually be a different function. We can see this by examining the LLVM IR.
=#
using BenchmarkTools

f(x,y) = x+y
@code_llvm f(2,3)

f(x,y,z) = x + y + z
@code_llvm f(1,2,3)

@which sum(1,2)
@code_llvm sum(1,2)

@code_llvm f(1.0,1)

function g(x,y)
    a = 4
    b = 2
    c = x + a
    d = b + c
    f(d, y)
end

@code_llvm g(2,3)

#=
Notice that when `f` is the function that takes in two `Int`s, `Ints` add to give an `Int` and thus `f` outputs an `Int`. When `f` is the function that takes two `Float64`s, `f` returns a `Float64`.

Thus in the above code `g` on two `Int` inputs is a function that has `Int`s at every step along the way and spits out an `Int`. We can use the `@code_warntype` macro to better see the inference along the steps of the function:
=#

@code_warntype g(2,3)

# what happens on mixtures?
@code_llvm f(2,3.0)

@code_warntype g(2.0, 3)

@code_llvm g(2.0,3)

#=
Multiple dispatch
Let's create functions for addition of two integers, two floats and then a fallback function for addition of two numbers
=#
ff(x::Int, y::Int) = x + y
ff(x::Float64, y::Float64) = x - y
ff(x::Number, y::Number) = x/y

ff(2,2)
ff(2.0,2.0)
ff(2,2.0)

@which +(2,2.1)

#=
Notice that the fallback method still specailizes on the inputs. 
The llvm IR for the below function call specializes on addition of Int and Float64
=#
@code_llvm ff(1,2.0)

#=
And that's essentially Julia's secret sauce: since it's always specializing its types on each function, if those functions themselves can infer the output, then the entire function can be inferred and generate optimal code, which is then optimized by the compiler and out comes an efficient function. If types can't be inferred, Julia falls back to a slower "Python" mode (though with optimizations in cases like small unions). Users then get control over this specialization process through multiple dispatch, which is then Julia's core feature since it allows adding new options without any runtime cost.
=#

function mixed_output(x,y)
    z = x + y
    rand() > 0.5 ? z : Float64(z)
end

@code_llvm mixed_output(1,1)

@code_warntype mixed_output(1,1)

#=
Note that f(x,y) = x+y is equivalent to f(x::Any,y::Any) = x+y, where Any is the maximal supertype of every Julia type. Thus f(x,y) = x+y is essentially a fallback for all possible input values, telling it what to do in the case that no other dispatches exist. 
**However, note that this dispatch itself is not slow, since it will be specailized on the input types.**
=#

#=
One way to ruin inference is to use an untyped container.
=#

a = [1.0, 2.0, 3.0] # stored in a stack since each element has fixed memory
b = ["hola", 2.3, [4]] # essentially pointer to array of pointers where each pointer points to an object. Hence allocated heap and thus slow

function bad_container(a)
    # note that this is just a function call `getindex`
    a[1]
end

@code_warntype bad_container(a)
@code_warntype bad_container(b)

#=
This is one common way that type inference can break down. Even if the array is all numbers, we can still break inference
=#
# f is defined as f(x,y) = x+y
x = Number[1.0,2]
function q(x)
    a = 2
    b = 3
    c = f(x[1],a) # output is Any because we cannot stack allocate c here since compile time output size is not known
    d = f(b,c)
    f(x[2],d)
end

@code_warntype q(x) 
# Note how inference breaks down in the second last line `%7 = Main.f(%6, d)::Any`
# This is because Number can be anything: Float64, Int32 etc. So the amount of memory cannot be decuded

@code_warntype q(AbstractFloat[1,2])
@code_warntype q([1,2]) # this returns an Int64 because the return type can be deduced

@btime q(Number[1.0,2.0])
@btime q([1.0,2.0])

@btime q(Number[1,2])
@btime q([1,2])

x = Number[1000,2000]
@btime q(x)
@btime q(Number[1000,2000])

x = Number[1.0,2.0]
@btime q(x)
@btime q(Number[1.0,2.0])