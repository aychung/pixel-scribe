FROM erlang:27.1.1.0-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.8.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app/pixel_scribe_backend && gleam export erlang-shipment

FROM erlang:27.1.1.0-alpine
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
USER webapp
COPY --from=build /app/pixel_scribe_backend/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
