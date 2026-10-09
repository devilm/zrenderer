FROM alpine:3.19 AS build

RUN apk update && \
    apk add --no-cache build-base autoconf libtool zlib-dev openssl-dev ldc dub && \
    mkdir /zrenderer

WORKDIR /zrenderer
COPY . .
RUN sed -i 's/\r$//' LuaD/build_clibs.sh
RUN dub clean && dub build --build=release --config=docker --force :server


FROM alpine:3.19

EXPOSE 11011

RUN apk update && \
    apk add --no-cache zlib openssl llvm-libunwind && \
    mkdir /zren && \
    addgroup --gid 5000 zren && \
    adduser -D -h /zren -s /bin/sh -u 5000 -G zren zren

WORKDIR /zren
COPY --from=build --chown=zren:zren /zrenderer/bin/zrenderer-server .
COPY --from=build --chown=zren:zren /zrenderer/resolver_data ./resolver_data
COPY --from=game-data --chown=zren:zren /sprite/인간족 ./data/sprite/인간족
COPY --from=game-data --chown=zren:zren /sprite/도람족 ./data/sprite/도람족
COPY --from=game-data --chown=zren:zren /sprite/방패 ./data/sprite/방패
COPY --from=game-data --chown=zren:zren /sprite/로브 ./data/sprite/로브
COPY --from=game-data --chown=zren:zren /sprite/악세사리 ./data/sprite/악세사리
COPY --from=game-data --chown=zren:zren /sprite/이팩트 ./data/sprite/이팩트
COPY --from=game-data --chown=zren:zren /sprite/shadow.* ./data/sprite/
COPY --from=game-data --chown=zren:zren /palette ./data/palette
COPY --from=game-data --chown=zren:zren /imf ./data/imf
COPY --from=game-data --chown=zren:zren /luafiles514 ./data/luafiles514

RUN mkdir -p /zren/output /zren/secrets && \
    chown zren:zren /zren /zren/output /zren/secrets

USER zren

CMD ["sh", "-c", "exec ./zrenderer-server --hosts=0.0.0.0 --port=${PORT:-11011} --resourcepath=. --outdir=output --tokenfile=secrets/accesstokens.conf"]
