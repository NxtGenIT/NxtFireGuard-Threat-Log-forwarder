# NxtFireGuard-Cisco-Identity-Services-Engine Integration

## Overview
NxtFireGuard's integration with Cisco Identity Services Engine (ISE) facilitates seamless log management by acting as a relay for ISE logs. Given that Cisco ISE does not natively support HTTP destinations for log messages, this Syslog container serves as an intermediary, forwarding the logs from Cisco ISE to NxtFireGuard.

## Prerequisites
- A valid NxtFireGuard license key.
- Docker installed on your system.
- Cisco ISE configured to send logs to an external Syslog server.

## Installation and Configuration

1. **Clone the Repository**:
    ```sh
    git clone https://github.com/NxtGenIT/NxtFireGuard-Cisco-Identity-Services-Engine.git
    cd NxtFireGuard-Cisco-Identity-Services-Engine
    ```

2. **Update the Docker Compose File**:
    - Open `docker-compose.yml` in a text editor.
    - Replace `<your-license-key>` with your purchased NxtFireGuard license key.
    - Replace <list-of-blocklists> with the names of the blocklists you want us to consider, such as my-blocklist-1, my-blocklist-2. You can create or delete blocklists on our Dashboard Website.

3. **Start the Syslog Container**:
    ```sh
    docker compose up -d
    ```

4. **Configure Cisco ISE**:
    - Log in to your Cisco ISE administration console.
    - Navigate to **Administration** > **System** > **Logging** > **Remote Logging Targets**.
    - Add a new Syslog target pointing to the Syslog container's IP address on port UDP/514.

5. **Verify Integration**:
    - Verify that Cisco ISE is sending logs to the Syslog Container.
    - Log in to your NxtFireGuard Dashboard at https://nxtfireguard.de/.
    - Navigate to the **Hosts** tab to verify that logs from Cisco ISE are being received.

## Support
For any issues or questions please contact our support team at [support@nxtgenit.de](mailto:support@nxtgenit.de).

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
