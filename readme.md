# remarkable-apps engine

This engine allows you to build custom software that runs on the reMarkable 2
e-ink tablet using Lua. It provides a minimal API for drawing pixels to the
screen (using the `rm2fb-client` wrapper through `/dev/fb0`) and reading from 
the pen (by reading from `/dev/input/event1`; N.B. this is the wrong path for
reMarkable 1).

# Compiling

Cross-compile with your cross-compiler.

I have found that `arm-linux-gnueabihf-gcc` works, which is available in 
Ubuntu (including Windows Subsystem for Linux) via apt.

From inside the `engine/` directory, `python3 build.py` will build Lua 5.3 and
the `engine` executable. This script includes referencing an alternative libm
due to linking problems I had with a mismatched glibc version.

The `build.py` script creates the ARM ELF in `engine/built/engine`. It also
attempts to `scp` the file to `root@remkarable:/home/root/engine`.

# Running Manually (reMarkable 2)

On the reMarkable 2, install `rm2fb-client` and `rm2fb-server`.

Shut down xochitl with `systemctl stop xochitl`. This is necessary because 
xochitl would otherwise continue to run "underneath" your app, responding to
pen and touch inputs and updating the screen.

Start the server with `rm2fb-server`.

Start your application with `rm2fb-client /home/root/engine <yourapp.lua>`.

To return to the normal reMarkable interface, stop the `rm2fb-server`, and start
xochitl again with `systemctl start xochitl`.

# Running with Remux (reMarkable 2)

[remux](https://rmkit.dev/apps/remux) is a launcher that can be installed from
toltec. After remux is installed, you can open the launcher by swiping up along
the left edge of the screen.

To add your app to the remux launch script, create the directory
`/home/root/apps`.

To add an entry, create a file `/home/root/apps/myapp.txt`. Give it contents 
like

```
call=rm2fb-client /home/root/engine /home/root/myapp.lua
```

Your app will now be available in the remux launcher, and remux will handle suspending xochitl / your app when you switch between them.

# Acknowledgements

rmkit

* https://github.com/rmkit-dev/rmkit/blob/master/src/rmkit/defines.h
* https://github.com/rmkit-dev/rmkit/blob/master/src/rmkit/fb/fb.cpy

remarkable2framebuffer

* https://github.com/ddvk/remarkable2-framebuffer/blob/master/src/client/main.cpp
* https://github.com/ddvk/remarkable2-framebuffer/blob/master/src/shared/ipc.cpp

