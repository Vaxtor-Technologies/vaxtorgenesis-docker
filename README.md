<p align="center">
<img src="design/robot.png" width="400" title="Vaxtor Robot">
</p>
<h3 align="center">Vaxtor’s high-performance Video Analytics Engine for Multi-Line Character Recognition</h3>
<br/>
<p align="center">
<img src="design/vaxgenesis.png" width="400" title="Vaxtor Robot">
</p>
<br/>

# Vaxtor Genesis - Docker Implementation Guide

This Docker image provides an easy, production-ready way to deploy and run Vaxtor’s generic reader (**VaxtorGenesis**) application. The application requires a valid license key for operation and offers multiple configurations to suit testing, production, and persistent data needs.


---

## 🏗️ Architecture & Internal Mechanics

The implementation cleanly separates the infrastructure layer from the application logic, ensuring an optimized and secure environment:

* **`Dockerfile`:** Supports multi-architecture builds (`amd64`, `arm64`). It installs the core `vaxtorgenesis` package, dynamically downloads the appropriate HASP driver (license management), and uses `tini` as a secure init system. 
* **`entrypoint.sh` (Infrastructure):** Acts as the primary initialization script. Launches the local HASP daemon (license manager), and dynamically updates `hasplm.ini` for network licensing or triggers the local license activation process.
* **`activate.sh`:** A secure script that handles standalone license activation by extracting a host fingerprint (C2V file) and authenticating directly with the Vaxtor License Server.
* **`default-app.sh` (Application):** Handles the execution of the main `vaxtorgenesis` binary in console mode. It includes a `DEBUG` mode toggle via environment variables.
* **`hasplm.ini`:** Contains the HASP daemon (license manager) settings.

### 🔌 Exposed Ports
* **`8444/tcp`**: Main Application / Web Interface.
* **`1947/tcp & udp`**: HASP Licensing daemon. Admin Control Center for license management will be available at `http://<containerip>:1947`.

---

## 🚀 Quick Start (Testing Mode)

To quickly test the application, use the following command. This command starts the container, applies the license specified in `<productkey>`, and exposes the application on port `8444`. 

```bash
docker run -it --rm -p 8444:8444 -e PRODUCT_KEY=<productkey> vaxtor/vaxtorgenesis
```

After running this command, the application will be accessible at `https://<containerip>:8444`.

> **⚠️ Important:** The above setup is intended for testing purposes only. Data, configuration, and license information will **not** persist once the container is stopped.

---

## 🔑 Licensing Strategies

You must provide a valid license for the Vaxtor OCR engine to operate.

> ℹ️ You can request a trial license at support@vaxtor.com

> **💡 Note:** If both the `LICENSE_SERVER_ADDR` and `PRODUCT_KEY` environment variables are set, the `PRODUCT_KEY` will be ignored, and the application will consume the license from the specified server.

### 1. Network License (License Server)
If you prefer to use a centralized license server instead of applying a local license, set the `LICENSE_SERVER_ADDR` environment variable. The `entrypoint.sh` will automatically configure the internal `hasplm.ini` to connect to it.

```bash
docker run -it --rm -p 8444:8444 -e LICENSE_SERVER_ADDR=192.168.0.88 vaxtor/vaxtorgenesis
```
*This command will consume the license from the license server at `192.168.0.88`.*

> ℹ️ For further infornation about how to start a License Server in your network please contact us at support@vaxtor.com


### 2. Standalone License & Persistent Licensing
To retain a local license across container restarts, mount a persistent volume for the HASP environment as follows:

```bash
docker run -it --rm -p 8444:8444 -e PRODUCT_KEY=<productkey> -v vaxtorgenesis-lic:/var/hasplm vaxtor/vaxtorgenesis
```
This command stores the license in the `vaxtorgenesis-lic` volume, allowing it to persist even if the container is recreated.

> **⚠️ License Volume Sharing:** The `vaxtorgenesis-lic` volume can be shared among multiple containers on the same host. However, **only one container can actively use the license at a time**. If you start a new container using the shared license volume while another container is running, the license will not function in the new container. To switch usage, stop the currently running container before starting a new one.

---

## 💾 Configuration & Full Persistence

### Persistent Configuration
To retain the application’s configuration across container restarts, mount a persistent volume for the configuration:

```bash
docker run -it --rm -p 8444:8444 -e PRODUCT_KEY=<productkey> -v vaxtorgenesis-config:/etc/vaxtorgenesis vaxtor/vaxtorgenesis
```

This command will persist the application config in the `vaxtorgenesis-config` volume.

### Full Persistence (License and Configuration)
To ensure that **both** the license and configuration persist, use the following setup:

```bash
docker run -d -p 8444:8444 -e PRODUCT_KEY=<productkey> -v vaxtorgenesis-config:/etc/vaxtorgenesis -v vaxtorgenesis-lic:/var/hasplm --name vaxtorgenesis vaxtor/vaxtorgenesis
```
This command will:
1. Keep the container running as a named instance (`vaxtorgenesis`).
2. Persist both the license and configuration in the specified volumes.

### Start and Stop the Container
Once the container has been started with a persistent setup, it can be controlled as follows:
```bash
docker start vaxtorgenesis
docker stop vaxtorgenesis
```

---

## 🛠️ Advanced Options

### Debug Mode
The `default-app.sh` script supports a debugging mode. By passing the `DEBUG=true` environment variable, the application will run with the `-debug` flag to increase the login messages verbosing.

```bash
docker run --rm -p 8444:8444 -e PRODUCT_KEY=<productkey> -e DEBUG=true vaxtor/vaxtorgenesis
```

---

## 🐳 Docker Compose Examples

For reproducible deployments, you can utilize `docker-compose.yml` to define your environment.

```yaml
version: '3.8'

services:
  # ---------------------------------------------------------
  # Profile: VaxGenesis Full Persistence (Standalone License)
  # ---------------------------------------------------------
  vaxtorgenesis-app:
    image: vaxtor/vaxtorgenesis:latest
    container_name: vaxtorgenesis
    ports:
      - "8444:8444"
      - "1947:1947" # Optional: Expose HASP port if needed for external queries
    environment:
      - PRODUCT_KEY=12345-ABCDE-67890-FGHIJ
      # - LICENSE_SERVER_ADDR=192.168.0.88
      # - DEBUG=true
    volumes:
      - vaxtorgenesis-config:/etc/vaxtorgenesis
      - vaxtorgenesis-lic:/var/hasplm
    restart: unless-stopped

volumes:
  vaxtorgenesis-config:
    name: vaxtorgenesis-app-config
  vaxtorgenesis-lic:
    name: vaxtorgenesis-hasp-lic
```