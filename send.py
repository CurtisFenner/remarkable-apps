import subprocess
import glob

# For me, -r is not replacing existing files, so send individual files.
for lua_file in glob.glob("luaapps/**/*.lua", recursive=True):
    print(lua_file)
    subprocess.run(["scp", lua_file, "root@remarkable:/home/root/" + lua_file])

subprocess.run(["scp", "engine/built/engine",
                "root@remarkable:/home/root/engine"])
