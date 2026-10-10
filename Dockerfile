# Settings writer in front of Eugen's official WARNO dedicated server.
# Rebuild this image when eugensystems/warno changes. Do not copy their server arguments.
FROM eugensystems/warno:latest

ARG UPSTREAM_DIGEST=unknown
LABEL org.opencontainers.image.source="https://github.com/suchamoneypit/WARHOST" \
      org.opencontainers.image.description="WARHOST writes WARNO dedicated-server settings from Unraid form fields, then starts Eugen's official entrypoint." \
      warno.upstream.digest="${UPSTREAM_DIGEST}"

COPY entrypoint-unraid.sh /server/entrypoint-unraid.sh
RUN chmod 755 /server/entrypoint-unraid.sh

WORKDIR /server
ENTRYPOINT ["/server/entrypoint-unraid.sh"]
