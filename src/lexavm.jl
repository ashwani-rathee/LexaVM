# module ValentineVM

# export real_main, julia_main
# export greet
# include("applicationprograms.jl")
using ReplMaker
using Debugger

"""
Structure that we are trying to achieve
-------------   -------------   -------------
|  User 1   |   |   User 2  |   |   User 3  |
-------------   -------------   -------------
    ↑                  ↑              ↑
    ↓                  ↓              ↓
----------------------------------------------
|  compiler        assembler     text-editor |
|                                            |
|   system and application programs          |
|         ---------------------------        | 
|         |    operating system     |        |
----------|     ------------        |---------
-         |     | computer  |       |        -
-         ------| hardware  |--------        -
-                ------------                -
-                                            -
"""

# memory = Array{UInt8}(undef, 5000)
memory = Array{UInt16}(undef, 65536)
memory[1] = 0 #counter 
println(memory[1])
# println(memory)

## Registers
R_R0 = 0
R_R1 = 0
R_R2 = 0
R_R3 = 0
R_R4 = 0
R_R5 = 0
R_R6 = 0
R_R7 = 0 
R_PC = 0
R_COND = 0 # tells about previous calculation
R_COUNT = 0
REG = Array{UInt16}(undef, 11)
## 

## Instructions in ValentineVM
# OP_BR = 0, #/* branch */
# OP_ADD,    #/* add  */
# OP_LD,    # /* load */
# OP_ST,     #/* store */
# OP_JSR,    #/* jump register */
# OP_AND,   # /* bitwise and */
# OP_LDR,  #  /* load register */
# OP_STR,   # /* store register */
# OP_RTI,   # /* unused */
# OP_NOT,   # /* bitwise not */
# OP_LDI,   # /* load indirect */
# OP_STI,   # /* store indirect */
# OP_JMP,  #  /* jump */
# OP_RES,   # /* reserved (unused) */
# OP_LEA,   # /* load effective address */
# OP_TRAP    #/* execute trap */
##

#=

    FL_POS = 1 << 0, /* P */
    FL_ZRO = 1 << 1, /* Z */
    FL_NEG = 1 << 2, /* N */

=# 

memory = Array{UInt8}(undef, 5000)

for (byte, x) in enumerate(memory)
    memory[byte] = 0x00
end

function debug(s::AbstractString)
    if size(ARGS)[1] > 1
        if ARGS[2] == "true"
            println(s)
        end
    end
end

function cpu(filepath::String, pushes = undef, startat = undef)

    global memory

    # Registers. https://www.swansontec.com/sregisters.html is a good reference. Based mostly on this

    A::UInt16 = 0x00 # Accumulator
    B::UInt16 = 0x00 # Open Register
    C::UInt16 = 0xff # Count Register
    D::UInt16 = 0x00 # Data Register
    RP::UInt16 = 0x01 # Read Pointer
    WP::UInt16 = 0x01 # Write Pointer
    SP::UInt16 = 0x00 # Stack Pointer

    # Interrupts

    UOI::Bool = false # User Input Overflow Interrupt. Goes back to line 1 in code

    # Flags

    OF::Bool = false # Open Flag, for any programmer use
    OF2::Bool = false
    OF3::Bool = false

    # Stack inits (memory pulled out for constant memory)

    stack::Array{UInt8} = Array{UInt8}(undef, 1000)

    for (byte, x) in enumerate(stack)
        stack[byte] = 0x00
    end

    if pushes !== undef
        for value in pushes
            SP += 1
            stack[SP] = value
        end
    end

    function wipeinput()
        i = 0

        while i != 255
            memory[i] = 0
        end
    end

    function isUInt(s::AbstractString)::Bool
        return tryparse(UInt, s) !== nothing
    end

    # File Line

    fileline::UInt64 = 1
    file::Array{String} = readlines(open(filepath))
    
    labels::Dict{String,Int} = Dict{String,Int}()

    for (linecount, line) in enumerate(file)
        try
            labelcheck = split(uppercase(replace(split(line, ";")[1], "," => " ")))[1]

            if labelcheck[1] == '.'
                push!(labels, replace(labelcheck, "." => "") => linecount)
            end
        catch BoundsError
        end
    end
    
    if startat !== undef
        if tryparse(UInt64, startat) !== nothing
            fileline = parseint(UInt64, startat)

        else
            fileline = labels[uppercase(startat)]
        end
    end

    debug("Labels: $labels\n")

    # Loads a value. Checks for register addressing, register values, characters, and numerical values. Note for characters, it will ONLY return one character
    function loadvalue(stringvalue::AbstractString)::UInt
        if isUInt(stringvalue)
            return parse(UInt16, stringvalue)

        else
            potential_char = match(r"\"(\\\\|\\\"|[^\"])*\"", stringvalue)

            if sizeof(potential_char) != 0
                return UInt(potential_char[1])
            end
        end

        if occursin("%", stringvalue)
            register = replace(stringvalue, "%" => "")

            if register == "A"
                return memory[A]

            elseif register == "B"
                return memory[B]

            elseif register == "C"
                return memory[C]

            elseif register == "D"
                return memory[D]

            elseif isUInt(replace(stringvalue, "%" => ""))
                return memory[parse(UInt, replace(stringvalue, "%" => ""))]

            else
                throw("Incorrect register value")
            end

        else
            if stringvalue == "A"
                return A

            elseif stringvalue == "B"
                return B

            elseif stringvalue == "C"
                return C

            elseif stringvalue == "D"
                return D

            elseif stringvalue == "RP"
                return RP

            elseif stringvalue == "WP"
                return WP

            else
                throw("Incorrect register value")
            end
        end
    end

    # Writes to register or location. Note, pointer addresses cannot be written to outside of their opcodes
    function writetolocation(location::AbstractString, value)
        location = string(location)

        if occursin("%", location)
            register = replace(location, "%" => "")

            if register == "A"
                memory[A] = value

            elseif register == "A"
                memory[B] = value

            elseif register == "C"
                memory[C] = value

            elseif register == "D"
                memory[D] = value

            else # Note, pointer addresses cannot be written to outside of their opcodes
                throw(
                    "Incorrect register value. Did you try to use a pointer? Note that pointers cannot be used in a address write except through their respective opcodes",
                )
            end

        else
            if location == "A"
                A = value

            elseif location == "B"
                B = value

            elseif location == "C"
                C = value

            elseif location == "D"
                D = value

            elseif location == "RP"
                RP = value

            elseif location == "WP"
                WP = value

            else # Note, SP cannot be written to
                throw("Incorrect location value")
            end
        end
    end

    while true
        if UOI
            fileline = 1
        end

        code::String = ""
        instruction::String = ""

        try
            code = replace(
                uppercase(replace(split(file[fileline], ";")[1], "," => " ")),
                "\t" => "",
            )

            instruction = split(code)[1]

        catch BoundsError
        end
        #println(code, instruction)

        debug("$fileline: $code")
        if size(split(code))[1] > 1
            arguments::Array{String} = split(code)[2:end]
            # println(arguments)
        end
        if instruction == "WRITE" # write [value, bit size]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                debug("	Writing $(arguments[1]) to $WP")

                if isUInt(arguments[1]) ||
                   arguments[1] in ["A", "B", "C", "D", "%A", "%B", "%C", "%D"]
                    value = loadvalue(arguments[1])

                    if parse(Int, arguments[2]) == 16
                        lower = Int(value % 0x100)
                        upper = Int(value / 0x100)

                        memory[WP] = lower
                        WP += 1
                        memory[WP] = upper

                    elseif parse(Int, arguments[2]) == 8
                        memory[WP] = value

                    else
                        throw("Incorrect bit size argument")
                    end

                else
                    for char in arguments[1]
                        memory[WP] = Int(char)
                        WP += 1
                    end
                end
            end

        elseif instruction == "STRWRITE" # strwrite [string]
            stringtowrite = replace(
                replace(split(file[fileline], ";")[1], "\t" => "")[10:end],
                "\\n" => "\n",
            )

            debugmessage =
                replace("	Wrote \"$(stringtowrite)\" to $WP through ", "\n" => "\n\t")

            for char in stringtowrite
                memory[WP] = Int(char)
                WP += 1
            end

            debugmessage = string(debugmessage, "$WP")
            debug(debugmessage)

        elseif instruction == "READ" # read [register, bit size]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                if parse(Int, arguments[2]) == 16
                    value = memory[RP]
                    RP += 1
                    value += memory[RP]

                elseif parse(Int, arguments[2]) == 8
                    value = memory[RP]

                else
                    throw("Incorrect bit size argument")
                end

                register = arguments[1]

                if register == "A"
                    A = value

                elseif register == "B"
                    B = value

                elseif register == "C"
                    C = value

                elseif register == "D"
                    D = value

                elseif register == "RP"
                    RP = value

                elseif register == "WP"
                    WP = value

                else
                    throw("Incorrect register value")
                end
            end

        elseif instruction == "LOAD" # load [register/pointer, value/register/%register]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                location::String = arguments[1]
                value = loadvalue(arguments[2])
                writetolocation(location, value)
                debug("	Wrote $value to $location")
            end

        elseif instruction == "PUSH" # push [value, bit size]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                value = loadvalue(arguments[1])

                if parse(Int, arguments[2]) == 16
                    lower = Int(value % 0x100)
                    upper = Int(value / 0x100)

                    SP += 1
                    stack[SP] = lower

                    debug("	Wrote $value to stack at position $SP")

                    SP += 1
                    stack[SP] = upper

                    debug("	Wrote $value to stack at position $SP")

                elseif parse(Int, arguments[2]) == 8
                    SP += 1
                    stack[SP] = value

                    debug("	Wrote $value to stack at position $SP")
                end
            end

        elseif instruction == "POP" # pop [location, bit size]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                if parse(Int, arguments[2]) == 16
                    value = stack[SP]
                    SP -= 1

                    value += stack[SP]
                    SP -= 1

                    writetolocation(arguments[1], value)
                    debug("	Wrote $value to $(arguments[1]) from position $(SP + 2)")
                    debug("	SP now at: $SP")

                elseif parse(Int, arguments[2]) == 8
                    value = stack[SP]
                    SP -= 1

                    writetolocation(arguments[1], value)
                    debug("	Wrote $value to $(arguments[1]) from position $(SP + 1)")
                    debug("	SP now at: $SP")

                else
                    throw("Incorrect bit size argument")
                end
            end


        elseif instruction == "GETIN"
            if size(arguments)[1] > 0
                throw("Too many arguments")

            else
                input::String = readline(STDIN)

                if sizeof(input) > 255
                    OUI = true

                else
                    for (i, char) in enumerate(input)
                        address = sizeof(memory)[1] - 255 + i

                        if !(address == sizeof(memory)[1])
                            memory[end-255+i] = char

                        else
                            break
                        end
                    end
                end
            end

        elseif instruction == "WIPEIN"
            if size(arguments)[1] > 0
                throw("Too many arguments")

            else
                wipeinput()
            end

        elseif instruction == "ADD" # add [location, value]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                dvalue = loadvalue(arguments[1])
                daddvalue = loadvalue(arguments[2])
                writetolocation(
                    arguments[1],
                    loadvalue(arguments[1]) + loadvalue(arguments[2]),
                )
                debug(
                    "	Added $daddvalue to $(arguments[1])\n\tOriginal Value: $dvalue\n\tNew Value: $(loadvalue(arguments[1]))",
                )
            end

        elseif instruction == "SUB" # sub [location, value]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                dvalue = loadvalue(arguments[1])
                dsubvalue = loadvalue(arguments[2])
                writetolocation(
                    arguments[1],
                    loadvalue(arguments[1]) - loadvalue(arguments[2]),
                )
                debug(
                    "	Subtracted $dsubvalue from $(arguments[1])\n\tOriginal Value: $dvalue\n\tNew Value: $(loadvalue(arguments[1]))",
                )
            end

        elseif instruction == "ITER" # iter [pointer]
            if size(arguments)[1] > 1
                throw("Too many arguments")

            else
                if arguments[1] == "RP"
                    RP += 1
                    debug("	Iterated RP to $RP")

                elseif arguments[1] == "WP"
                    WP += 1
                    debug("	Iterated WP to $WP")
                end
            end

        elseif instruction == "JMP" # jmp [line]
            if size(arguments)[1] > 1
                throw("Too many arguments")

            else
                fileline = loadvalue(arguments[1])
                continue
            end

        elseif instruction == "JEQ" # Jumps if two values are equal: jeq [location, value, line]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                debug(
                    "	ARG1: $(loadvalue(arguments[1]))\n\tARG2: $(loadvalue(arguments[2]))",
                )
                debug(
                    "	ARG1 == ARG2: $(loadvalue(arguments[1]) == loadvalue(arguments[2]))",
                )

                if loadvalue(arguments[1]) == loadvalue(arguments[2])
                    fileline = loadvalue(arguments[3])
                    continue
                end
            end

        elseif instruction == "JNEQ" # Jumps if two values are not equal: jneq [location, value, line]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                debug(
                    "	ARG1: $(loadvalue(arguments[1]))\n\tARG2: $(loadvalue(arguments[2]))",
                )
                debug(
                    "	ARG1 != ARG2: $(loadvalue(arguments[1]) != loadvalue(arguments[2]))",
                )

                if loadvalue(arguments[1]) != loadvalue(arguments[2])
                    fileline = loadvalue(arguments[3])
                    continue
                end
            end

        elseif instruction == "JGT" # Jumps if value 1 is greater than value 2: jgt [location, value, line]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                debug(
                    "	ARG1: $(loadvalue(arguments[1]))\n\tARG2: $(loadvalue(arguments[2]))",
                )
                debug("	ARG1 > ARG2: $(loadvalue(arguments[1]) > loadvalue(arguments[2]))")

                if loadvalue(arguments[1]) > loadvalue(arguments[2])
                    fileline = loadvalue(arguments[3])
                    continue
                end
            end

        elseif instruction == "JNGT" # Jumps if value 1 is not greater than value 2: jngt [location, value, line]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                debug(
                    "	ARG1: $(loadvalue(arguments[1]))\n\tARG2: $(loadvalue(arguments[2]))",
                )
                debug(
                    "	ARG1 !> ARG2: $(!(loadvalue(arguments[1]) > loadvalue(arguments[2])))",
                )

                if !(loadvalue(arguments[1]) > loadvalue(arguments[2]))
                    fileline = loadvalue(arguments[3])
                    continue
                end
            end

        elseif instruction == "JLT" # Jumps if value 1 is less than value 2: jlt [location, value, line]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                debug(
                    "	ARG1: $(loadvalue(arguments[1]))\n\tARG2: $(loadvalue(arguments[2]))",
                )
                debug("	ARG1 < ARG2: $(loadvalue(arguments[1]) < loadvalue(arguments[2]))")

                if loadvalue(arguments[1]) < loadvalue(arguments[2])
                    fileline = loadvalue(arguments[3])
                    continue
                end
            end

        elseif instruction == "JNLT" # Jumps if value 1 is not less than value 2: jlt [location, value, line]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                debug(
                    "	ARG1: $(loadvalue(arguments[1]))\n\tARG2: $(loadvalue(arguments[2]))",
                )
                debug(
                    "	ARG1 !< ARG2: $((loadvalue(arguments[1]) < loadvalue(arguments[2])))",
                )

                if !(loadvalue(arguments[1]) < loadvalue(arguments[2]))
                    fileline = loadvalue(arguments[3])
                    continue
                end
            end

        elseif instruction == "JIF" # Jumps if open flag is true: jif [flag, line]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                debug(
                    "$(arguments[1]): $(arguments[1] == "OF" ? OF : (arguments[1] == "OF2" ? OF2 : (arguments[1] == "OF3" ? OF3 : "Error")))",
                )

                flag = arguments[1]
                line = parse(Int, arguments[2])

                if flag == "OF"
                    if OF
                        fileline = line
                        continue
                    end

                elseif flag == "OF2"
                    if OF2
                        fileline = line
                        continue
                    end

                elseif flag == "OF3"
                    if OF3
                        fileline = line
                        continue
                    end
                end
            end

        elseif instruction == "TOGGLE" # Toggles flag value: toggle [flag]
            if size(arguments)[1] > 1
                throw("Too many arguments")

            else
                flag = arguments[1]

                if flag == "OF"
                    OF = !OF
                    debug("	OF: $OF")

                elseif flag == "OF2"
                    OF2 = !OF2
                    debug("	OF2: $OF2")

                elseif flag == "OF3"
                    OF3 = !OF3
                    debug("	OF3: $OF3")
                end
            end

        elseif instruction == "PRINT" # print [char amount]
            if size(arguments)[1] > 2
                throw("Too many arguments")

            else
                i = RP + loadvalue(arguments[1])

                while RP < i
                    print(Char(memory[RP]), "")
                    RP += 1
                end

                debug("")
            end

        elseif instruction == "GOTO" # goto [label]
            fileline = labels[replace(arguments[1], "." => "")]

        elseif instruction == "CALL" # call [filename, amount to pop, label/line to jump to]
            if size(arguments)[1] > 3
                throw("Too many arguments")

            else
                call::String = split(replace(split(file[fileline], ";")[1], "," => " "))[2]

                debug("	Loading $call as potential call.")

                debug("	$call does $(ifelse(in('/', call), "", "not "))have a folder.")
                if !in('/', call)
                    call = string("std/", call)
                    debug("	Loading $call as std module.")
                end

                debug("	$call does $(ifelse(in('/', call), "", "not "))have an extension.")
                if !in('.', call)
                    call = string(call, ".jlasm")
                    debug("	Loading $call as jlasm file.")
                end

                call = replace(call, ":" => "/")

                if size(arguments)[1] >= 2
                    i = 1

                    if loadvalue(arguments[2]) != 0
                        vals_to_push::Array{UInt8} =
                            Array{UInt8}(undef, loadvalue(arguments[2]))

                        while i <= loadvalue(arguments[2])
                            vals_to_push[i] = stack[SP]
                            SP -= 1
                            i += 1
                        end

                        debug("	Loading File: $(split(call, "/")[end])\n")

                        if size(arguments)[1] == 3
                            try
                                stackvals = cpu(call, vals_to_push, loadvalue(arguments[3]))

                            catch Exception
                                stackvals = cpu(call, vals_to_push, arguments[3])
                            end

                        else
                            stackvals = cpu(call, vals_to_push)
                        end

                        for value in stackvals
                            SP += 1
                            stack[SP] = value
                        end

                    else
                        if size(arguments)[1] == 3
                            try
                                cpu(call, loadvalue(arguments[3]))

                            catch Exception
                                cpu(call, arguments[3])
                            end

                        else
                            cpu(call)
                        end
                    end

                else
                    cpu(call)
                end
            end

        elseif instruction == "HLT"
            break
        end

        fileline += 1
        # println(fileline, size(file)[1])
        if fileline > size(file)[1]
            break
        end
    end

    if pushes !== undef
        vals_to_return::Array{UInt8} = Array{UInt8}(undef, SP)
        i = 0

        while SP > 1
            vals_to_return[i] = stack[SP]
            SP -= 1
            i += 1
        end

        return vals_to_return
    end
end

function greet()
    println("Hello!!")
end
line_count =0

function texteditor()
    println("Let's make a text editor: ")
    # Julia program to take 
    # multi-lined input from user
    
    # line_count = 0
    
    # println("Enter multi-lined text, press Ctrl-D when done")
    println("Enter a line of text,press Ctrl-D when done")
    
    # Calling readlines() function
    lines = readline()
    
    # Loop to count lines
    for line in lines   
        global line_count += 1
    end
    
    println("total no.of.lines : ", line_count)
    
    println(lines)
    
    # Getting type of Input values
    println("type of input: ", typeof(lines))
    return
end
data= ""

function Input(prompt)
    print(prompt)
    readline()
end

function parse_to_expr(s)
    quote Meta.parse($s) end
end

function menu()
    while true
        str = """
        1) run => to run asm tests
        2) exit => to exit this menu
        3) texteditor => to run the text editor
        4) scheduling => to run first come first serve scheduling 
        """
        println(str)
        # sleep(5)
        # data = "scheduling"
        print("Enter Command:")
        global data = readline()

        @show data
        if  data =="run"
            if size(ARGS)[1] > 0
                debug("Loading File: $(ARGS[1])")
                cpu(ARGS[1])
                println("Program Ended!!")
            else
                debug("Error: No file loaded.\nPlease type: julia cpu.jl [path/to/file]")
            end
        elseif data == "exit"
            break

        elseif data == "texteditor"
            println("TextEditor")
            # run(`pwd`)
            # include("texteditor.jl")
            texteditor()

        elseif data == "scheduling"
            println("Scheduling")
            println("Please choose a scheduling method: ")
            algs = ["FCFS","SJF(NP)","SJF(P)","PRIORITY(NP)","PRIORITY(P)","ROUNDROBIN","BANKERALG"]
            println(algs) 
            name = readline()
            println(control_program(algs[parse(Int,name)]))
        else
            println("Data:",data)
            # global data = readline()
            # sleep(5)
            println("No command select, Try Again!!")
        end
    end

end

function resource_allocator()
    # Resource allocator – manages and allocates resources.

end

function kernel()
    # Kernel – the one program running at all times (all else being
    # application programs).

end

function control_program(alg)
    #Control program – controls the execution of user programs and
    # operations of I/O devices .
    println("Hello")
    println(alg)
    fcfs()
end


function fcfs()
    # proces id's"
    println("Enter number of processes: ")
    data = readline()
    println(data)
    # processes = [1,2,3]
    n = parse(Int,data)
    println(n, typeof(n))

    print("Enter Process ids: ")
    process_id = readline()
    println(process_id)
    processes =[]
    for i in collect(1:2:2*n)
        push!(processes,parse(Int,process_id[i]))
    end
    println(processes)
    
    # println(n)
    # # burst time of all responses
    # burst_time =[10,5,8]
    print("Enter Burst times: ")
    burst_times =readline()
    burst_time = []
    println(burst_times)
    for i in collect(1:2:2*n)
        push!(burst_time,parse(Int,burst_times[i]))
    end

    wt=[]
    push!(wt,0)
    for i in 2:n[1]
        push!(wt, burst_time[i-1] + wt[i-1] )
    end
    

    tat=[]
    for i in 1:n[1]
        push!(tat,burst_time[i] + wt[i])
    end
    println(processes)
    println(burst_time)
    println(wt)
    println(tat)
    return [1,2,3]
end

function main()
    greet()
    menu()
end

Debugger.@enter main()

# end
# end # module2#1
# endtexte