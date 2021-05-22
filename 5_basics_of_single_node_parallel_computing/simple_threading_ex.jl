Threads.nthreads()

origin = zeros(100000000)
function affine()
    origin .+= 3.0
    sleep(3)
    origin .*= 2.0
    sleep(3)
    origin .+= 4.0
    sleep(3)
    origin
end
@time affine()

origin = zeros(100000000)
function affine_mt()
    Threads.@threads for i in 1:3
        if i == 1
            origin .+= 3.0
            sleep(3)
        elseif i==2
            origin .*= 2.0
            sleep(3)
        else
            origin .+= 4.0
            sleep(3)
        end
    end
    origin
end

@time affine_mt()