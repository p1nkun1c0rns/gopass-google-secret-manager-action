FROM google/cloud-sdk:315.0.0-slim

COPY entrypoint.sh /entrypoint.sh
RUN apt-get install -y gnupg2 git rng-tools && \
    apt-get clean && \
    mkdir -p ~/.ssh && \
    curl -Lso /tmp/gopass.deb https://github.com/gopasspw/gopass/releases/download/v1.10.1/gopass_1.10.1_linux_amd64.deb && \
    dpkg -i /tmp/gopass.deb && \
    rm -f /tmp/gopass.deb && \
    chmod a+x /entrypoint.sh

WORKDIR /tmp
ENTRYPOINT ["/entrypoint.sh"]
