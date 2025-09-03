FROM debian:13-slim AS base

LABEL org.opencontainers.image.description="Base image for running and debugging webdriver implementations"

# Install the base requirements to run and debug webdriver implementations:
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install --no-install-recommends --no-install-suggests -y \
    xvfb \
    xauth \
    ca-certificates \
    x11vnc \
    fluxbox \
    rxvt-unicode \
    curl \
    tini \
    gpg \
  # Remove obsolete files:
  && apt-get clean \
  && rm -rf \
    /usr/share/doc/* \
    /var/cache/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Patch xvfb-run to support TCP port listening (disabled by default):
RUN sed -i 's/LISTENTCP=""/LISTENTCP="-listen tcp"/' /usr/bin/xvfb-run

# Avoid permission issues with host mounts by assigning a user/group with
# uid/gid 1000 (usually the ID of the first user account on GNU/Linux):
RUN useradd -u 1000 -m -U webdriver

WORKDIR /home/webdriver

COPY entrypoint.sh /usr/local/bin/entrypoint
COPY vnc-start.sh /usr/local/bin/vnc-start

# Configure Xvfb via environment variables:
ENV SCREEN_WIDTH=1440
ENV SCREEN_HEIGHT=900
ENV SCREEN_DEPTH=24
ENV DISPLAY=:0

ENTRYPOINT ["entrypoint"]

################################################################################

FROM base

ARG FINGERPRINT=35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
ARG TARGETPLATFORM

# Install Cloudflare Bypass FastAPI
ADD https://github.com/atta-1/cfbypass.git /home/webdriver/cfbypass

# Install Camoufox (special version of Firefox)
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y python3 pip python3-venv libgtk-3-0 libx11-xcb1 libasound2 \
  && cd cfbypass \
  && python3 -m venv .venv \
  && .venv/bin/pip install -r requirements.txt \
  && .venv/bin/python -m camoufox fetch \
  && apt-get clean \
  && rm -rf \
    /usr/share/doc/* \
    /var/cache/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Install the latest version of Geckodriver:
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt update \
  && apt install --no-install-recommends --no-install-suggests -y jq \
  && ARCH=$([ "$TARGETPLATFORM" = "linux/arm64" ] && echo "aarch64" || echo "linux64") \
  && BASE_URL=https://github.com/mozilla/geckodriver/releases/download \
  && VERSION=$(curl -sL https://api.github.com/repos/mozilla/geckodriver/releases/latest | jq | grep tag_name | cut -d '"' -f 4) \
  && curl -sL -vvv "$BASE_URL/$VERSION/geckodriver-$VERSION-linux-$ARCH.tar.gz" | tar -xz -C /usr/local/bin \
  && apt-get remove -y jq \
  && apt-get clean \
  && rm -rf \
    /usr/share/doc/* \
    /var/cache/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

USER webdriver

ENTRYPOINT ["entrypoint", "geckodriver"]

CMD ["--port", "4444"]

EXPOSE 4444
EXPOSE 5900
EXPOSE 8000
