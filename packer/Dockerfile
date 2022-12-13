FROM hashicorp/packer as packer

FROM hashicorp/terraform as terraform

FROM cytopia/ansible as ansible
COPY --from=packer /bin/packer /bin/
COPY --from=terraform /bin/terraform /bin/
RUN apk add --update \
 python3 \
 curl \
 which \
 bash \
 openssh-client \
 jq
RUN bash <(curl -sSL https://sdk.cloud.google.com) \
 --disable-prompts --install-dir=/opt
ENV PATH $PATH:/opt/google-cloud-sdk/bin
