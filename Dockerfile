ARG BASE_IMAGE=docker.1ms.run/library/ubuntu:24.04
FROM ${BASE_IMAGE}

MAINTAINER ngocpq <phungquangngoc@gmail.com>

#############################################################################
# Requirements
#############################################################################

ARG APT_MIRROR=mirrors.aliyun.com
# 使用国内 apt 源（镜像站/代理慢时非常明显）；兼容 Ubuntu 20.04 的 sources.list 与 Ubuntu 24.04 的 ubuntu.sources
RUN set -eux; \
  if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
    sed -i \
      -e "s|http://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|https://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|http://security.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|https://security.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|http://ports.ubuntu.com/ubuntu-ports|http://${APT_MIRROR}/ubuntu-ports|g" \
      /etc/apt/sources.list.d/ubuntu.sources; \
  fi; \
  if [ -f /etc/apt/sources.list ]; then \
    sed -i \
      -e "s|http://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|https://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|http://security.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|https://security.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" \
      -e "s|http://ports.ubuntu.com/ubuntu-ports|http://${APT_MIRROR}/ubuntu-ports|g" \
      /etc/apt/sources.list; \
  fi

RUN \
  apt-get update -y && \
  apt-get install software-properties-common -y && \
  apt-get update -y && \
  apt-get install -y openjdk-11-jdk \
                git \
                build-essential \
                subversion \
                perl \
                curl \
                unzip \
                cpanminus \
                make \
                && \
  rm -rf /var/lib/apt/lists/*

# Defects4J checkout 会从 /defects4j/project_repos 做本地 clone；在 overlayfs 下默认 hardlink 可能失败
RUN git config --global core.hardlinks false

# Java version
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64

# Timezone
ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


#############################################################################
# Setup Defects4J
#############################################################################

# ----------- Step 1. Clone defects4j from github --------------
WORKDIR /
RUN git clone https://github.com/rjust/defects4j.git defects4j

# ----------- Step 2. Initialize Defects4J ---------------------
WORKDIR /defects4j
RUN cpanm --installdeps .
RUN ./init.sh

# overlayfs 上从本地 repo clone 会因 hardlink 失败；只补一刀：给 git clone 加 --no-hardlinks
# 放在 init 之后，最大化利用镜像层缓存（避免因为小改动导致 init 相关下载重跑）
RUN sed -i 's/return \"git clone /return \"git clone --no-hardlinks /' framework/core/Vcs/Git.pm

# ----------- Step 3. Add Defects4J's executables to PATH: ------
ENV PATH="/defects4j/framework/bin:${PATH}"  
#--------------
