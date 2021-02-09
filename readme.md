# Compiling

Cross-compile with your cross-compiler.

I have found that `arm-linux-gnueabihf-gcc` works, which is available in 
Ubuntu (including Windows Subsystem for Linux) via apt.

# Running

On the reMarkable 2, install `rm2fb-client` and `rm2fb-server`.

Shut down xochitl with `systemctl stop xochitl`.

Start the server with `rm2fb-server`.

Start your application with `rm2fb-client <yourbinary>`.

To return to the normal reMarkable interface, stop the `rm2fb-server`, and start
xochitl again with `systemctl start xochitl`.

(untested on reMarkable 1, but it might work)

# Acknowledgements

rmkit

* https://github.com/rmkit-dev/rmkit/blob/master/src/rmkit/defines.h
* https://github.com/rmkit-dev/rmkit/blob/master/src/rmkit/fb/fb.cpy

remarkable2framebuffer

* https://github.com/ddvk/remarkable2-framebuffer/blob/master/src/client/main.cpp
* https://github.com/ddvk/remarkable2-framebuffer/blob/master/src/shared/ipc.cpp

