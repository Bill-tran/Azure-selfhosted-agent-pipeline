
   
## kubectl #####################################################################
ARG KUBECTL_VERSION=1.20.2
FROM bitnami/kubectl:$KUBECTL_VERSION as kubectl

## Kaniko ######################################################################
FROM gcr.io/kaniko-project/executor:latest as kaniko

## NodeJS ######################################################################
FROM ubuntu:20.04 as base

# Related to Azure CLI issue https://github.com/Azure/azure-cli/issues/6408
ENV PYTHONIOENCODING utf8

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive

RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

ENV AZP_WORK /workspace

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        iputils-ping \
        gnupg \
        lsb-release \
        jq \
        libcurl4 \
        libicu66 \
        libssl1.0 \
        libunwind8 \
        python3 \
        python3-pip \
        gettext \
        netcat \
        azure-cli \
        openjdk-11-jdk && \
            rm -rf /var/cache/oracle-jdk11-installer

# SonarQube
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
RUN export JAVA_HOME
RUN export PATH=$PATH:$JAVA_HOME/bin
RUN echo $PATH

# Node and NPM
ARG NODE_VERSION=14.x
RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION | bash - && \
    apt-get update && apt-get install -y --no-install-recommends \
        nodejs && \
    node -v && npm -v # smoke test

# Kustomize
RUN cd /usr/local/bin && curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
ENV kustomize /usr/local/bin/kustomize

# Kubeseal
ARG KUBESEAL_VERSION=0.16.0
ENV kubeseal /usr/local/bin/kubeseal
RUN curl -sL https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-linux-amd64 -o /usr/local/bin/kubeseal && \
    chmod +x /usr/local/bin/kubeseal && \
    kubeseal --version
    
# Kubectl
COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
ENV kubectl /usr/local/bin/kubectl

# Kaniko
COPY --from=kaniko /kaniko/executor /usr/local/bin/executor
ENV executor /usr/local/bin/executor

# Azure
# Commeting out because its causing problems to other pipelines. Related to this issue: https://github.com/Azure/azure-cli/issues/14774
# RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null && \
#     AZ_REPO=$(lsb_release -cs) && \
#     echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list && \
#     apt-get update -qq && \
#     apt-get install -y --no-install-recommends azure-cli && \
#     rm -rf /var/lib/apt/lists/* && \

RUN az extension add -n azure-devops && \
    az version # smoke test

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /etc/apt/sources.list.d/* && \
    apt-get autoremove -y

WORKDIR /azp

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
