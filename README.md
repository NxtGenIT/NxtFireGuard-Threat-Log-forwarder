# NxtFireGuard-Syslog-Forwarder

## Overview
Threat Log Forwarder for Cisco Firepower and ISE as well as T-Pot to NxtFireGuard.

## Prerequisites
- An active NxtFireGuard license key.
- Docker installed on your system.

## Setup and Usage

### Clone the Repository
To get started, clone the repository and navigate to the project directory:

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
docker compose up syslog-ng -d
```

## Usage for T-Pot

### Set Up the Environment File:
Rename `.env.example` to `.env.`
Update the values in the `.env` file as per your setup requirements. Note that the default `ELK_URL` is preconfigured for standard T-Pot installations.

Start the Logstash Container:

```sh
docker compose up logstash -d
```
