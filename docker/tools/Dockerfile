FROM python:3.11-bookworm

RUN apt-get update && \
    apt-get install -y \
      default-mysql-client \
      bash-completion \
      procps \
      dnsutils \
      net-tools \
      iputils-ping \
      locales \
      make \
      jq \
      fzf \
      vim \
      curl \
      wget \
      groff \
      less \
      sudo \
      gcc \
      tar \
      git \
      tmux

# ロケール設定
RUN echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=ja_JP.UTF-8
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# aws cli インストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

COPY docker/tools/bin/mysql-login /usr/local/bin/mysql-login
