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
 git \
 build-base \
 libffi-dev \
 openssl-dev \
 bzip2-dev \
 zlib-dev \
 xz-dev \
 readline-dev \
 sqlite-dev \
 tk-dev \
 jq
RUN bash <(curl -sSL https://sdk.cloud.google.com) \
 --disable-prompts --install-dir=/opt
ENV PATH $PATH:/opt/google-cloud-sdk/bin

RUN bash <(curl https://pyenv.run)
ENV PYENV_ROOT=/root/.pyenv
ENV PATH $PYENV_ROOT/bin:$PATH
RUN pyenv install 3.8.16
