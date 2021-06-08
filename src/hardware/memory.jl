#memory

# Memory Layout for a simple batch system

"""
---------
|       |
|  os   |
|       |
---------
|       |
| user  |
|program|
| area  |
---------
"""

# This is all the memory we have and we work with
memory = Array{UInt8}(undef, 5000)