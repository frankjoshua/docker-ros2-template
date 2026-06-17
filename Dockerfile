FROM frankjoshua/ros2:lyrical AS base
# Single source of truth for shared dependencies. Both `dev` and `prod` inherit this stage,
# so they cannot drift apart. Any dependency NOT declared in a src/*/package.xml must be added
# here — never installed ad hoc inside a running dev container (that change would not reach prod).
RUN apt-get update && apt-get install -y \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ---- dev: what VS Code opens. base + a non-root user + an interactive shell. ----
FROM base AS dev
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# Noble-based images ship a default user at UID 1000 (e.g. "ubuntu"); remove it so ours can take 1000.
RUN if id -u $USER_UID >/dev/null 2>&1; then userdel "$(id -un $USER_UID)"; fi
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update && apt-get install -y sudo \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*
ENV SHELL=/bin/bash
USER $USERNAME
CMD ["/bin/bash"]

# ---- prod: base + workspace baked and built. ----
FROM base AS prod
WORKDIR /ros2_ws
COPY src ./src
RUN apt-get update \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -r -y \
    && rm -rf /var/lib/apt/lists/*
RUN . /opt/ros/$ROS_DISTRO/setup.sh \
    && colcon build --symlink-install
COPY ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "run", "example_pkg", "example_node"]
