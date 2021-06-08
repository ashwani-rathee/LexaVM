# This file is our operating system- virtual os
include("computerhardware.jl")

#=
This program acts as intermediary between a user of a computer
and the computer hardware Its task is to use computer hardware in an 
efficient manner by controlling and coordinating the use of 
hardware among various application pograms for the users.

Operating system goals:
- Execute user programs and make solving user problems easier.
- Make the computer system convenient to use.
=#

# We need a resource allocator
# Resource allocator – manages and allocates resources

# We need a control program 
# Control program – controls the execution of user programs and operations of I/O devices

# We need a kernel
# Kernel – the one program running at all times (all else being application programs).

