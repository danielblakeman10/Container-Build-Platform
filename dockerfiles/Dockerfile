# Multi-Stage Dockerfile - Production Best Practices
# This Dockerfile demonstrates build efficiency, security, and small image size

# ============================================
# Stage 1: Build (install dependencies, compile)
# ============================================
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go module files first (cache layer)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build with security hardening
# - CGO_ENABLED=0: No CGO = statically linked = no shared library issues
# - -ldflags: Strip debug info and symbols (smaller, less info leakage)
# - -trimpath: Remove file system paths from binary (security)
RUN CGO_ENABLED=0 GOOS=linux \
    go build -ldflags="-w -s -trimpath" \
    -o /server \
    .

# Run tests during build (fail CI if tests fail)
RUN CGO_ENABLED=0 GOOS=linux go test -v -cover ./...

# ============================================
# Stage 2: Download Certs (prepare ca-certificates)
# ============================================
FROM alpine:3.19 AS certs
RUN apk --update add ca-certificates

# ============================================
# Stage 3: Production (minimal runtime image)
# ============================================
FROM scratch

# Import certificates
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy binary from builder
COPY --from=builder /server /server

# Non-root user security
# Note: scratch has no user management, so we use user namespace mapping
# or switch to distroless for user management
USER 65534:65534

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/server", "/health"]

# Expose port
EXPOSE 8080

# Run the binary
ENTRYPOINT ["/server"]
