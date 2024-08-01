# NxtFireGuard-Cisco-Identity-Services-Engine Integration

## Overview
This Syslog container serves as an intermediary, forwarding logs from Cisco ISE and Cisco Firepower to NxtFireGuard.

## Prerequisites
- A valid NxtFireGuard license key.
- Docker installed on your system.

## Installation and Configuration

1. **Clone the Repository**:
    ```sh
    git clone https://github.com/NxtGenIT/NxtFireGuard-Syslog-forwarder.git
    cd NxtFireGuard-Syslog-forwarder
    ```

2. **Update the Docker Compose File**:
    - Open `syslog/syslog-ng.conf` in a text editor.
    - Replace `<your-license-key>` with your purchased NxtFireGuard license key.

3. **Start the Syslog Container**:
    ```sh
    docker compose up -d
    ```

## Support
For any issues or questions please create an Issue or contact our support team at [support@nxtgenit.de](mailto:support@nxtgenit.de).

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
