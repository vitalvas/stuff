FROM alpine as builder

ENV KUBE_VERSION="v1.19.3"
ENV KUSTOMIZE_VERSION="v3.8.5"
ENV VAULT_VERSION="1.5.5"

RUN apk add --update ca-certificates wget

RUN wget https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl

RUN wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
RUN tar -xzvf /kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz

RUN wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
RUN unzip vault_${VAULT_VERSION}_linux_amd64.zip

FROM alpine

RUN apk add --update ca-certificates

COPY --from=builder kubectl /usr/local/bin
COPY --from=builder kustomize /usr/local/bin
COPY --from=builder vault /usr/local/bin

RUN chmod a+x /usr/local/bin/*

