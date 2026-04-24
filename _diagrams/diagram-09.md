---
title: "REST Request Sequence — Per-Request Overhead"
excalidraw_file: "rest-order-sequence.excalidraw"
order: 9
slide_ref: "34"
description: "Full lifecycle of a single REST request showing DNS, TCP, TLS, HTTP overhead vs gRPC streaming."
prev_url: "/diagrams/diagram-08/"
prev_title: "Diagram 08"
next_url: "/diagrams/diagram-10/"
next_title: "Diagram 10"
---

Shows the 8-12 round trips of a single REST request. Contrast with gRPC streaming where this overhead is paid once and 1,000 messages flow back on the same connection.
