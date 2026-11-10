# Settings writer in front of Eugen's official WARNO dedicated server.
# Rebuild this image when eugensystems/warno changes. Do not copy their server arguments.
FROM eugensystems/warno:latest

ARG UPSTREAM_DIGEST=unknown
LABEL org.opencontainers.image.source="https://github.com/matthewariel/WARHOST" \
      org.opencontainers.image.description="WARHOST writes WARNO dedicated-server settings from Unraid form fields, then starts Eugen's official entrypoint." \
      warno.upstream.digest="${UPSTREAM_DIGEST}"

# DepotDownloader (GPL-2.0, https://github.com/SteamRE/DepotDownloader) fetches only
# Config.ini for a bare Workshop id at start. Eugen's image supplies wget and
# sha256sum. It does not supply python3, which the WebUI and this unpack need.
# Workshop files are never stored in the image.
ARG DEPOTDOWNLOADER_VERSION=3.4.0
ARG DEPOTDOWNLOADER_SHA256=a999dec66b4850fc961bd50366696d23c2d0fad7b18790e6a5647b2f19097a53
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3 \
 && rm -rf /var/lib/apt/lists/* \
 && wget -q -O /tmp/depotdownloader.zip "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOTDOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip" \
 && printf '%s  %s\n' "$DEPOTDOWNLOADER_SHA256" /tmp/depotdownloader.zip | sha256sum -c - \
 && python3 -m zipfile -e /tmp/depotdownloader.zip /opt/depotdownloader \
 && chmod 755 /opt/depotdownloader/DepotDownloader \
 && ln -s /opt/depotdownloader/DepotDownloader /usr/local/bin/DepotDownloader \
 && rm /tmp/depotdownloader.zip

COPY entrypoint-unraid.sh /server/entrypoint-unraid.sh
COPY webui /server/webui
RUN chmod 755 /server/entrypoint-unraid.sh /server/webui/launch.sh \
 && useradd --system --user-group --no-create-home --shell /usr/sbin/nologin warhost-web

WORKDIR /server
ENTRYPOINT ["/server/entrypoint-unraid.sh"]
