# https://mcr.microsoft.com/en-us/product/devcontainers/base/about
FROM mcr.microsoft.com/devcontainers/base:dev-ubuntu-22.04

RUN apt-get update && \
    apt-get install -y \
      default-mysql-client \
      bash-completion \
      procps \
      net-tools \
      iputils-ping \
      locales \
      make \
      jq \
      fzf \
      vim \
      curl \
      wget \
      git \
      groff \
      less \
      sudo \
      gcc \
      tar \
      dnsutils

# ロケール設定
RUN echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=ja_JP.UTF-8
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# golang インストール
# https://go.dev/doc/install
RUN wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz

# k9s インストール
# https://github.com/derailed/k9s/tree/latest
RUN GOBIN=/usr/local/bin /usr/local/go/bin/go install github.com/derailed/k9s@latest

# aws cli インストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# kubectl インストール
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN curl -LO https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# eksctl インストール
# https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/setting-up-eksctl.html#setting-up-eksctl-linux
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && \
    mv /tmp/eksctl /usr/local/bin

# https://developer.hashicorp.com/terraform/install
ENV TERRAFORM_VERSION=1.10.3
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    terraform -install-autocomplete

# Kustomizeのインストール
# https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash && \
    mv kustomize /usr/local/bin/

# helmインストール
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# helmのリポジトリにeks, kedaを追加
RUN helm repo add eks https://aws.github.io/eks-charts && \
    helm repo add kedacore https://kedacore.github.io/charts && \
    helm repo update

# Argo CD CLI インストール
# https://argo-cd.readthedocs.io/en/stable/cli_installation/#download-with-curl
RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd && \
    rm argocd-linux-amd64

RUN curl -sSL https://install.python-poetry.org | POETRY_HOME=/home/vscode/.pypoetry python3 - && \
    chown -R vscode:vscode /home/vscode/.pypoetry

RUN wget https://github.com/alexei-led/spotinfo/releases/download/1.0.7/spotinfo_linux_amd64 && \
    chmod 755 spotinfo_linux_amd64 && \
    mv spotinfo_linux_amd64 /usr/local/bin/spotinfo