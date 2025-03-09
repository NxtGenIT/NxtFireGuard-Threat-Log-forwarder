# NxtFireGuard-Syslog-Forwarder

## Overview
Threat Log Forwarder for Cisco Firepower, Cisco ISE, and T-Pot to NxtFireGuard.

## Prerequisites
- An active NxtFireGuard license key.
- A Debian-based or Ubuntu system with sudo privileges, properly set up and running.

## Setup and Usage

### Download the Latest Release
To get started, download the latest release from the following link:
[Latest Release](https://github.com/NxtGenIT/NxtFireGuard-Threat-Log-forwarder/releases/latest).

Extract the tar file and navigate to the project directory:

```sh
wget v.x.y.tar.gz
 tar -xf v.x.y.tar.gz
 cd NxtFireGuard-Threat-Log-forwarder
```

### Installation
Make the `install.sh` script executable:
```sh
chmod +x install.sh
```

Run the install script with sudo (required for system update, upgrade, and Docker installation):
```sh
sudo ./install.sh
```

Follow the prompts:

Examples:
- Enter your License Key (you can find it here: [Account Dashboard](https://nxtfireguard.de/pages/dashboard/account))
  ```
  [your_license_key]: 4WPHKY3K-9RWJXKD3-VKLAUG96-E7N7ALMF
  ```
- What would you like to name your Threat-Log-Forwarder?
  ```
  [forwarder-name]: nfg-threat-log-fwd-01
  ```
- Do you want to integrate with Cisco-FMC and/or Cisco-ISE (enable RUN_SYSLOG)?
  ```
  (true/false) [false]: true
  ```
- Do you want to integrate with T-Pot and enable Logstash (enable RUN_LOGSTASH)?
  ```
  (true/false) [false]: false
  ```

### Post-Installation Steps
Log out and log back in to apply the user to the Docker group.

To start the selected service(s), run:
```sh
./run.sh start
```

### Usage
Manage the service using the following commands:
```sh
systemctl status nfg-threat-forwarder.service   # Check service status
systemctl start nfg-threat-forwarder.service    # Start the service
systemctl stop nfg-threat-forwarder.service     # Stop the service
systemctl restart nfg-threat-forwarder.service  # Restart the service
```


### Validation and Documentation
To complete and validate the setup, refer to the respective documentation for your host integration:
- [Cisco ISE Integration](https://docs.nxtfireguard.de/docs/Hosts/cisco-identity-services-engine#next-steps)
- [Cisco FMC Integration](https://docs.nxtfireguard.de/docs/Hosts/cisco-firewall-management-center#next-steps)
- [T-Pot Integration](https://docs.nxtfireguard.de/docs/Hosts/honeypot-tpot#next-steps)

## Support
If you encounter any issues or have questions, feel free to contact our support team through our [contact form](https://nxtfireguard.de/pages/contact-form?topic=support).

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

