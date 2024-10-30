# NxtFireGuard-Syslog-Forwarder

## Overview
Threat Log Forwarder for Cisco Firepower and ISE as well as T-Pot to NxtFireGuard.

For complete documentation, please visit our [Documentation Page](https://docs.nxtfireguard.de/docs/Hosts/syslog-forwarder).

## Prerequisites
- An active NxtFireGuard license key.
- Docker installed on your system.

## Setup and Usage

### Download the latest release
To get started, download the latest release and navigate to the project directory:

```sh
git clone https://github.com/NxtGenIT/NxtFireGuard-Syslog-forwarder.git
cd NxtFireGuard-Syslog-forwarder
```

## Usage for Cisco FMC and Cisco ISE

### Configure the Syslog-ng Configuration File:
Open syslog/syslog-ng.conf in a text editor.
Replace `<your-license-key>` with your valid NxtFireGuard license key.

Start the Syslog Container:

```sh
docker compose up nfg-syslog-ng -d
```

## Usage for T-Pot

### Set Up the Environment File:
Rename `.env.example` to `.env`
Update the values in the `.env` file as per your setup requirements. Note that the default `ELK_URL` is preconfigured for standard T-Pot installations.

Start the Logstash Container:

```sh
docker compose up nfg-logstash -d
```

## Support
If you encounter any issues or have questions, feel free to [open an issue](https://github.com/NxtGenIT/NxtFireGuard-Syslog-forwarder/issues) on GitHub or reach out to our support team through our [contact form](https://nxtfireguard.de/pages/contact-form?topic=support).

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

