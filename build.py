import glob
import os
import subprocess

LUA_MAINS = set(["lua.c", "luac.c"])
source_files = ["framebuffer.c", "input.c", "main.c", "interpreter.c"]
intermediates = ["built/luas/all.a"]
libraries = ["dl", "rt"]
exe = "built/curtis"

################################################################################

# Build Lua 5.3.6.
# Build Lua into a static library.
if not os.path.exists("built/luas/all.a"):
    for c_path in glob.glob("../lua-5.3.6/src/*.c"):
        c_directory, c_file = os.path.split(c_path)
        target = "built/luas/" + c_file + ".o"
        if c_file not in LUA_MAINS and not os.path.exists(target):
            subprocess.run(["arm-linux-gnueabihf-gcc"]
                           + ["-Wall", "-Wextra",  "-O3"]
                           + ["-c", c_path]
                           + ["-o", target]
                           + ["-lm"])
    subprocess.run(["arm-linux-gnueabihf-ar", "rcs"]
                   + ["built/luas/all.a"]
                   + glob.glob("built/luas/*.o"))

command = (["arm-linux-gnueabihf-gcc"]
           + ["-o", exe]
           + ["-I../lua-5.3.6/src"]
           + source_files
           + intermediates
           # N.B.: The GCC version between my toolchain and the reMarkable
           # differs, so instead provide the reMarkable's libm.
           # This must FOLLOW intermediates, because ld only uses a .so if
           # previous arguments referenced the symbol.
           + ["../rmlib/lib/libm.so.6"]
           + ["-l" + lib for lib in libraries])
subprocess.run(command)

# Send the compiled ELF to the reMarkable 2.
print("Tried building", exe)
subprocess.run(["scp", exe, "root@remarkable:/home/root/curtis"])
