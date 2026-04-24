---
title: "RPC Architecture — REST at Boundary, gRPC Inside"
excalidraw_file: "rpc-architecture.excalidraw"
order: 8
slide_ref: "34"
description: "When to use REST vs gRPC architecturally — public API boundary vs internal service mesh."
prev_url: "/diagrams/diagram-07/"
prev_title: "Diagram 07"
next_url: "/diagrams/diagram-09/"
next_title: "Diagram 09"
---

Architectural context: REST at the public API boundary (browsers, partners), gRPC for internal pod-to-pod calls. Quarkus Demo 05 runs both protocols simultaneously on the same service.
