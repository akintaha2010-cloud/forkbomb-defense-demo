# Build from the repo root:  docker build -t forkdemo:latest .
FROM scratch
COPY img/busybox /bin/busybox
COPY bomb.sh /bomb.sh
RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ["/bin/busybox", "mkdir", "-p", "/tmp"]
RUN ["/bin/busybox", "chmod", "1777", "/tmp"]
