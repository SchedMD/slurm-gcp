FROM hashicorp/packer as packer

FROM hashicorp/terraform as terraform

FROM cytopia/ansible as ansible
COPY --from=packer /bin/packer /bin/
COPY --from=terraform /bin/terraform /bin/
RUN apk add --update \
    bash \
    build-base \
    bzip2-dev \
    curl \
    gcc \
    git \
    jq \
    libffi-dev \
    openssh-client \
    openssl-dev \
    python3 \
    python3-dev \
    readline-dev \
    sqlite-dev \
    tk-dev \
    which \
    xz-dev \
    zlib-dev
RUN pip3 install pipenv

RUN bash <(curl -sSL https://sdk.cloud.google.com) \
 --disable-prompts --install-dir=/opt
ENV PATH $PATH:/opt/google-cloud-sdk/bin

RUN bash <(curl https://pyenv.run)
ENV PYENV_ROOT=/root/.pyenv
ENV PATH $PYENV_ROOT/bin:$PATH
RUN pyenv install 3.8.16
