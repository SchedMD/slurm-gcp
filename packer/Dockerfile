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
    py3-wheel \
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

RUN python3 -m venv /venv --system-site-packages
ENV PATH=/venv/bin:$PATH
RUN pip3 install --upgrade pip
RUN pip3 install "Cython<3.0" pyyaml --no-build-isolation
