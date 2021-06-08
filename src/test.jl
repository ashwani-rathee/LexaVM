# # Julia program to take input from user
  
# # prompt to input
# print("What's your name ? \n\n") 
  
# # Calling rdeadline() function
# while true
#     name = readline()
#     println("The name is ", name)
#     print("\n\n")
# end
# # typeof() determines the datatype.
# println("Type of the input is: ", typeof(name)) 

# module TestModule1

# export func1, print_nprocs

using Distributed
using SharedArrays
using ProgressMeter
using Interpolations

function func1()
    n = 2000000
    arr = SharedArray{Float64}(n)
    @sync @distributed for i = 1:n
        arr[i] = i^2
    end
    res = sum(arr)
    return res
end

function print_nprocs()
    return nworkers()
end
# end
for i in 1:5
    func1()
    print_nprocs()
    sleep(5)
end
