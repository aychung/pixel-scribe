FROM oven/bun:1.3.9-alpine AS bun

FROM ghcr.io/gleam-lang/gleam:v1.18.0-erlang-alpine AS frontend
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun
WORKDIR /app/pixel_scribe_frontend
COPY pixel_scribe_frontend/gleam.toml pixel_scribe_frontend/manifest.toml ./
RUN gleam deps download
COPY pixel_scribe_frontend/src ./src
COPY pixel_scribe_frontend/assets ./assets
RUN gleam run -m lustre/dev build

FROM erlang:27.1.1.0-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.18.0-erlang-alpine /bin/gleam /bin/gleam
COPY pixel_scribe_backend /app/pixel_scribe_backend
RUN rm -rf /app/pixel_scribe_backend/priv/public && mkdir -p /app/pixel_scribe_backend/priv/public
COPY --from=frontend /app/pixel_scribe_frontend/dist/. /app/pixel_scribe_backend/priv/public/
RUN cd /app/pixel_scribe_backend && gleam export erlang-shipment

FROM erlang:27.1.1.0-alpine
ENV PORT 80
ENV HOST 0.0.0.0
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
USER webapp
COPY --from=build /app/pixel_scribe_backend/build/erlang-shipment /app
WORKDIR /app/pixel_scribe_backend
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["run"]
