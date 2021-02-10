import glob
import os
import subprocess

LUA_MAINS = set(["lua.c", "luac.c"])

# Build Lua 5.3.6.
for c_path in glob.glob("../lua-5.3.6/src/*.c"):
    c_directory, c_file = os.path.split(c_path)
    target = "built/luas/" + c_file + ".o"
    if c_file not in LUA_MAINS and not os.path.exists(target):
        subprocess.run(["arm-linux-gnueabihf-gcc"]
                       + ["-Wall", "-Wextra",  "-O3"]
                       + ["-c", c_path]
                       + ["-o", target]
                       + ["-lm"])

# Build Lua into a static library.
# For some reason, Lua is depending on glibc@2.29 for math functions
# (cos, atan2, etc), but the reMarkable only has 2.27.
# Statically linking it covers up this problem.
subprocess.run(["arm-linux-gnueabihf-ar", "rcs"]
               + ["built/luas/all.a"]
               + glob.glob("built/luas/*.o"))

# Build the app.
flags = ["-Wall", "-Wextra", "-O3", "-flto"]
source_files = ["framebuffer.c", "input.c", "main.c", "interpreter.c"]
intermediates = ["built/luas/all.a"]
libraries = ["dl", "rt", "m"]
exe = "built/curtis"
command = (["arm-linux-gnueabihf-gcc"]
           + flags
           + ["-o", exe]
           + ["-Wl,-L", "-Wl,../rmlib/lib"]
           + ["-I../lua-5.3.6/src"]
           + source_files
           + glob.glob("../rmlib/lib/*.so")
           + intermediates
           + ["-l" + lib for lib in libraries])

print("\t".join(command))
subprocess.run(command)

# Send the compiled ELF to the reMarkable 2.
remote = "root@remarkable"
subprocess.run(["scp", exe, remote + ":/home/root/curtis"])
