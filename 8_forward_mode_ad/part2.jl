#=
Forward mode AD as JVP

The primitive action of forward-mode AD is f'(x)v! This is also known as a Jacobian-vector product, or jvp for short.

- Say you are given a function `f(x,y)=x^2*sin(y)` and you want to calculate its directional derivative in the direction (a,b). You can do it easily using Dual numbers. You only need to put the components a,b into the derivative component of the Dual numbers (i.e define `xx.derivs = [a,0]` and `yy.derivs = [0,b]`).

In other words we calcuate f(x0 + aϵ, y + bϵ) - f(x0, y0). If we wish to calculate the directional derivative in another direction, we could repeat the calculation with a different `v`. A better solution is to use another independent epsilon `ϵ`, expanding `x=x0+a1ϵ1+a2ϵ2` and putting `ϵ1ϵ2=0`.

Thus, for a function which takes R^n as input, we can perform the following algebra:

`d = d0 + v_1ϵ_1 + v_2ϵ_2 + ... + v_nϵ_n` where d0 is the primal vector and assume ϵ_iϵ_j = 0. This gives us:

`f(d) = f(d0) + f'(d0)v_1ϵ_1 + f'(d0)v_2ϵ_2 + ... + f'(d0)v_nϵ_n`.

It makes sense to set v_i as basis vectors. Also setting f'(d0) = J, we get:

`f(d) = f(d0) + Je_1ϵ_1 + Je_2ϵ_2 + ... + Je_nϵ_n`
=#

#=
Application: solving nonlinear equations using the Newton method
=#
using ForwardDiff, StaticArrays

function newton_step(f, x_θ)
    J = ForwardDiff.jacobian(f, x_θ)
    δ = J \ f(x_θ)
    x_θ - δ
end

function newton(f, x_θ)
    x = x_θ
    for i=1:10
        x = newton_step(f, x)
        @show x
    end
    x
end

ff(xx) = ( (x,y) = xx; SVector(x^2 + y^2 - 1, x - y) )
x0 = SVector(3.0, 5.0)
x = newton(ff, x0)