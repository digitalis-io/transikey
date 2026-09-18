# SSH target for testing Transikey: accepts OpenBao signed certificates
# (TrustedUserCAKeys) and OpenBao one-time passwords (vault-ssh-helper via
# PAM). Development only: no host key persistence, no hardening.
FROM ubuntu:22.04

ARG TARGETARCH
ARG SSH_HELPER_VERSION=0.2.4

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/* \
 && base="https://releases.hashicorp.com/vault-ssh-helper/${SSH_HELPER_VERSION}" \
 && zip="vault-ssh-helper_${SSH_HELPER_VERSION}_linux_${TARGETARCH}.zip" \
 && cd /tmp \
 && curl -fsSL "${base}/${zip}" -o "${zip}" \
 && curl -fsSL "${base}/vault-ssh-helper_${SSH_HELPER_VERSION}_SHA256SUMS" -o SHA256SUMS \
 && grep " ${zip}\$" SHA256SUMS | sha256sum -c - \
 && unzip -q "${zip}" -d /usr/local/bin \
 && chmod 0755 /usr/local/bin/vault-ssh-helper \
 && rm -f "/tmp/${zip}" /tmp/SHA256SUMS \
 && mkdir -p /run/sshd /etc/vault-ssh-helper.d \
 && useradd --create-home --shell /bin/bash ubuntu

COPY sshd_config /etc/ssh/sshd_config
COPY pam-sshd /etc/pam.d/sshd
COPY vault-ssh-helper.hcl /etc/vault-ssh-helper.d/config.hcl
COPY entrypoint.sh /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
