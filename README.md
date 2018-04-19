# Protocol Buffers + Docker
All inclusive protoc suite, powered by Docker and Alpine Linux.

## What's included:
- protobuf 3.5.1
- gRPC 1.8.3
- Google Well Known Types are automatically included (via `google/`)
- Go related tools compiled with 1.8.1, gRPC support is built-in:
  - github.com/golang/protobuf/protoc-gen-go
  - github.com/gogo/protobuf/protoc-gen-gofast
  - github.com/gogo/protobuf/protoc-gen-gogo
  - github.com/gogo/protobuf/protoc-gen-gogofast
  - github.com/gogo/protobuf/protoc-gen-gogofaster
  - github.com/gogo/protobuf/protoc-gen-gogoslick
  - github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger
  - github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway

## Supported languages
- C
- C++
- C#
- Java / JavaNano (Android)
- JavaScript
- Objective-C
- Python
- Ruby
- Go
- Swift 4
- Rust

## Usage
```
$ docker run --rm znly/protoc --help
Usage: /usr/bin/protoc [OPTION] PROTO_FILES
```

Don't forget you need to bind mount your files:
```
$ docker run --rm -v $(pwd):$(pwd) -w $(pwd) znly/protoc --python_out=. -I. myfile.proto
```

## Google Well Known Types
They are embedded in the image and are included by `protoc` automatically.
They accessible via `google/protobuf/`:
```protobuf
syntax = "proto3";

import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";
```

## Gogo
`gogo.proto` is embedded in the image and can be included with:
```protobuf
syntax = "proto3";

import "github.com/gogo/protobuf/gogoproto/gogo.proto";
```

## Image Size
The current image is about ~130mb and one layer. Most the space is spent on Go tools.
All the binaries are UPX'ed. Including the Swift stdlib.
