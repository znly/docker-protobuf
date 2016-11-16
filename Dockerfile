FROM alpine:3.4
MAINTAINER Steeve Morin <steeve@zen.ly>

ENV GRPC_VERSION=1.0.1      \
    PROTOBUF_VERSION=3.1.0  \
    SWIFT_PROTOBUF_VERSION=0.9.24  \
    GOPATH=/go

COPY upx /usr/bin/upx
RUN apk add --no-cache build-base curl automake autoconf libtool git go zlib-dev && \
    curl -L https://github.com/QuentinPerez/docker-alpine-swift-protobuf/releases/download/$SWIFT_PROTOBUF_VERSION/export-lib-bcd56c4.tar | tar xv -C / && \
    curl -L https://github.com/google/protobuf/archive/v${PROTOBUF_VERSION}.tar.gz | tar xvz && \
    curl -L https://raw.githubusercontent.com/QuentinPerez/docker-alpine-swift-protobuf/master/ressources/ld_library_path.patch > /ld_library_path.patch && \
    cd /protobuf-${PROTOBUF_VERSION} && \
        autoreconf -f -i -Wall,no-obsolete && \
        (cd ./src/google/protobuf/compiler/ && patch < /ld_library_path.patch) && \
        rm -rf autom4te.cache config.h.in~ && \
        ./configure --prefix=/usr --enable-static=no && \
        make && make install && \
        rm -rf `pwd` && cd / && \
    rm /ld_library_path.patch && \
    git clone --recursive -b v${GRPC_VERSION} https://github.com/grpc/grpc.git && \
    cd /grpc/third_party/protobuf && git checkout v${PROTOBUF_VERSION} && \
    cd /grpc && \
        make plugins && make install-plugins prefix=/usr && \
        rm -rf `pwd` && cd / && \
    curl -L https://github.com/grpc/grpc-java/archive/v${GRPC_VERSION}.tar.gz | tar xvz && \
    cd /grpc-java-${GRPC_VERSION}/compiler/src/java_plugin/cpp && \
        g++ -I. -lprotoc -lprotobuf -lpthread --std=c++0x -s -o protoc-gen-grpc-java *.cpp && \
        install -c protoc-gen-grpc-java /usr/bin/ && \
        rm -rf /grpc-java-${GRPC_VERSION} && cd / && \
    go get -ldflags "-w -s" \
        github.com/golang/protobuf/protoc-gen-go \
        github.com/gogo/protobuf/protoc-gen-gofast \
        github.com/gogo/protobuf/protoc-gen-gogo \
        github.com/gogo/protobuf/protoc-gen-gogofast \
        github.com/gogo/protobuf/protoc-gen-gogofaster \
        github.com/gogo/protobuf/protoc-gen-gogoslick \
        github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger \
        github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && \
    install -c /go/bin/* /usr/bin/ && \
    rm -rf /go/* && \
    upx --lzma --best /usr/bin/protoc-gen-* && \
    mkdir -p /protobuf/google/protobuf && \
        for f in any duration descriptor empty struct timestamp wrappers; do \
            curl -L -o /protobuf/google/protobuf/${f}.proto https://raw.githubusercontent.com/google/protobuf/master/src/google/protobuf/${f}.proto; \
        done && \
    mkdir -p /protobuf/google/api && \
        for f in annotations http; do \
            curl -L -o /protobuf/google/api/${f}.proto https://raw.githubusercontent.com/grpc-ecosystem/grpc-gateway/master/third_party/googleapis/google/api/${f}.proto; \
        done && \
    mkdir -p /protobuf/github.com/gogo/protobuf/gogoproto && \
        curl -L -o /protobuf/github.com/gogo/protobuf/gogoproto/gogo.proto https://raw.githubusercontent.com/gogo/protobuf/master/gogoproto/gogo.proto && \
    apk del build-base curl automake autoconf libtool git go zlib-dev && \
    find /usr/lib -name "*.a" -delete -or -name "*.la" -delete && \
    apk add --no-cache libstdc++ make

ENTRYPOINT ["/usr/bin/protoc", "-I/protobuf"]
