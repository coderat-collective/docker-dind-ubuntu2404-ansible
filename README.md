# Docker-in-Docker Ubuntu 24.04 with Ansible

A Docker image based on [geerlingguy/docker-ubuntu2404-ansible](https://hub.docker.com/r/geerlingguy/docker-ubuntu2404-ansible) with Docker-in-Docker (DIND) capabilities pre-installed. This image is designed for Molecule testing scenarios where you need to run Docker containers within Docker containers.

## Overview

This image provides a complete environment for testing Ansible roles that manage Docker containers. It comes pre-configured with:

- Ubuntu 24.04 LTS (Noble)
- Ansible
- Docker CE (Community Edition)
- Docker Compose plugin
- Python Docker SDK (`python3-docker`)
- Cron service
- Systemd init system (from base image)
- VFS storage driver (required for DIND)

Docker and cron services are enabled via systemd and start automatically when the container launches.

## Base Image

This image is built on top of [geerlingguy/docker-ubuntu2404-ansible:latest](https://hub.docker.com/r/geerlingguy/docker-ubuntu2404-ansible), which provides a solid foundation with systemd support and Ansible pre-installed. The base image uses systemd as the init system, allowing services to be managed naturally via `systemctl`.

## Included Software

| Software | Version | Purpose |
|----------|---------|---------|
| Docker CE | Latest | Container runtime |
| Docker Compose | Latest (plugin) | Multi-container orchestration |
| docker-ce-cli | Latest | Docker command-line interface |
| containerd.io | Latest | Container runtime |
| python3-docker | Latest | Python Docker SDK for Ansible |
| cron | Latest | Scheduled task execution |

## Usage

### In Molecule Scenarios

To use this image in your Molecule test scenarios, configure your `molecule.yml` or inventory file with the required container settings:

```yaml
platforms:
  - name: test-container
    image: ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest
    privileged: true
    cgroupns_mode: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    command: ""
```

### Example: Molecule Inventory Configuration

```yaml
all:
  hosts:
    test_client:
      ansible_host: test_client
      ansible_connection: community.docker.docker
      container_image: "ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest"
      container_command: ""
      container_privileged: true
      container_super_privileged: true
```

### Direct Docker Run

```bash
docker run -d \
  --name dind-test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest

# Wait a few seconds for systemd to start Docker
sleep 5

# Verify Docker is running
docker exec dind-test docker info
```

## Container Requirements

For Docker-in-Docker to function properly, the container **must** be run with the following settings:

### Required Settings

1. **Privileged Mode**: `privileged: true`
   - Grants the container elevated permissions needed to run Docker daemon

2. **Cgroup Namespace**: `cgroupns_mode: host`
   - Allows the container to use the host's cgroup namespace

3. **Cgroup Volume Mount**: `/sys/fs/cgroup:/sys/fs/cgroup:rw`
   - Provides read-write access to cgroup filesystem

### Why These Are Required

Docker-in-Docker requires access to system-level resources that are normally restricted in containers. The privileged mode, host cgroup namespace, and cgroup volume mount work together to provide the nested Docker daemon with the permissions and resources it needs to manage containers.

## Storage Driver

This image is configured to use the **VFS** (Virtual File System) storage driver for Docker.

### Why VFS?

The VFS storage driver is used because:

1. **Compatibility**: Works reliably in nested container scenarios
2. **No Kernel Dependencies**: Doesn't require specific kernel features
3. **Stability**: Avoids issues with overlayfs and other COW filesystems in DIND scenarios

### Trade-offs

- **Performance**: VFS is slower than overlay2 or other copy-on-write drivers
- **Space Usage**: Uses more disk space as it creates full copies of images
- **Use Case**: Ideal for testing environments, not recommended for production workloads

The VFS driver configuration is set in `/etc/docker/daemon.json`:

```json
{
  "storage-driver": "vfs"
}
```

## Building Locally

To build this image locally:

```bash
docker build -t docker-dind-ubuntu2404-ansible:local .
```

To build with a specific tag:

```bash
docker build -t docker-dind-ubuntu2404-ansible:v1.0.0 .
```

## GitHub Actions

This repository includes a `.github/workflows/build.yml` file that automatically builds and pushes the Docker image to the GitHub Container Registry (ghcr.io).

### Pipeline

The workflow automatically builds and pushes the Docker image in the following scenarios:

1. **On every push**: Builds and pushes to any branch
2. **Monthly schedule**: Automatically rebuilds on the 1st of every month at 00:00 UTC

### Automatic Builds

- **On every push**: Builds and pushes with `latest` tag (all branches)
- **Monthly schedule**: Keeps the image updated with the latest base image and security updates

### Image Tags

Images are tagged as:

- `latest` - Most recent build from any branch

### Registry Location

After the workflow completes, images are available at:

```
ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest
```

You can view the package on GitHub at: **Packages** → **docker-dind-ubuntu2404-ansible** in the repository sidebar.

### Pulling the Image

```bash
docker pull ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest
```

## Testing the Image

### Using the Published Image

To verify Docker works inside the container using the published image from GitHub Container Registry:

```bash
# Pull the latest image
docker pull ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest

# Start the container
docker run -d \
  --name dind-test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  ghcr.io/coderat-collective/docker-dind-ubuntu2404-ansible:latest

# Wait a few seconds for Docker to initialize
sleep 5

# Verify Ansible is installed
docker exec dind-test ansible --version

# Execute docker commands inside the container
docker exec dind-test docker info
docker exec dind-test docker run hello-world

# Check Docker service status
docker exec dind-test systemctl status docker

# Clean up
docker stop dind-test
docker rm dind-test
```

### Using a Locally Built Image

If you built the image locally:

```bash
docker run -d \
  --name dind-test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  docker-dind-ubuntu2404-ansible:local

# Wait and test as above
sleep 5
docker exec dind-test docker info

# Clean up
docker stop dind-test
docker rm dind-test
```

## Troubleshooting

### Docker daemon fails to start

**Symptom**: `Cannot connect to the Docker daemon` errors

**Solutions**:
1. Verify privileged mode is enabled
2. Check cgroup volume is mounted correctly
3. Check service status: `docker exec <container> systemctl status docker`
4. Review Docker logs: `docker exec <container> journalctl -u docker`
5. Ensure host kernel supports required features

### Permission denied errors

**Symptom**: `permission denied while trying to connect to the Docker daemon socket`

**Solutions**:
1. Ensure container is running in privileged mode
2. Check that cgroupns_mode is set to `host`
3. Verify systemd started properly: `docker exec <container> systemctl is-system-running`
4. Check if Docker service is active: `docker exec <container> systemctl is-active docker`

### Storage driver errors

**Symptom**: Errors related to storage driver or filesystem

**Solutions**:
1. VFS is configured by default and should work in most scenarios
2. Check `/etc/docker/daemon.json` exists and is valid JSON
3. Review Docker daemon logs for specific storage errors

## Contributing

Contributions are welcome! Please submit issues or pull requests to improve this image.

## License

This image builds upon [geerlingguy/docker-ubuntu2404-ansible](https://github.com/geerlingguy/docker-ubuntu2404-ansible) and follows the same licensing terms.

## Maintainer

- coderat-collective

## Related Projects

- [geerlingguy/docker-ubuntu2404-ansible](https://github.com/geerlingguy/docker-ubuntu2404-ansible) - Base image
- [Molecule](https://molecule.readthedocs.io/) - Ansible testing framework
- [Docker](https://www.docker.com/) - Container platform
