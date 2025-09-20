FROM golang:1.23.6-bookworm AS build

WORKDIR /build

# Copy full source
ADD . /build

RUN make build

FROM debian:stable-slim

COPY --from=build /build/bin/rewardflow-avs /usr/local/bin/rewardflow-avs

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Add labels for RewardFlow AVS
LABEL org.opencontainers.image.title="RewardFlow AVS Performer"
LABEL org.opencontainers.image.description="RewardFlow AVS Performer for Uniswap V4 Hook Reward Distribution"
LABEL org.opencontainers.image.vendor="RewardFlow"
LABEL org.opencontainers.image.version="1.0.0"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["/usr/local/bin/rewardflow-avs"]
