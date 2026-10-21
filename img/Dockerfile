FROM scratch
COPY busybox /bin/busybox
COPY bomb.sh /bomb.sh
RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ["/bin/busybox", "mkdir", "-p", "/tmp"]
RUN ["/bin/busybox", "chmod", "1777", "/tmp"]
