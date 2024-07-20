import os
import requests
import time
from ftd_connector import ftd_connection
import re
import logging

# Logging configuration
logger = logging.getLogger('shun_logger')
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


def get_blocklists(blocklist_urls):
    '''
    Function takes blocklist_urls which is a list and gets each blocklist via requests.
    Returns ips_to_block which is a list containing all IPs from all blocklists specified in the blocklist_urls list.
    '''
    blocklist_ips = set()
    for blocklist_url in blocklist_urls:
        try:
            response = requests.get(blocklist_url)
            response.raise_for_status()
            ips = re.findall(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', response.text)
            blocklist_ips.update(ips)
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching {blocklist_url}: {e}")

    return blocklist_ips

    


def get_currently_blocked_ips(host, ssh_user, ssh_password):
    '''
    Logs into the host via SSH, runs the command to get the currently blocked IPs,
    and captures the output in a list. Returns a set of these IPs to ensure uniqueness.

    Args:
    host (str): The IP address or hostname of the SSH server.
    ssh_user (str): The username to use for SSH login.
    ssh_password (str): The password to use for SSH login.

    Returns:
    set: A set of currently blocked IPs.
    '''
    try:
        device = ftd_connection(host, ssh_user, ssh_password)
        output = device.send_command_clish("show shun")
    except Exception as e:
        logger.error(f"Exception occurred during get_currently_blocked_ips {e}")
        return set()

    # Extract IP addresses using a regular expression
    ips = re.findall(r'shun \(.*?\) (\d+\.\d+\.\d+\.\d+)', output)
    return set(ip for ip in ips if ip != '0.0.0.0')


def block_ip(host, ssh_user, ssh_password, ip):
    try:
        device = ftd_connection(host, ssh_user, ssh_password)
        output = device.send_command_clish(f"shun {ip}")
        logger.info(f"{host} shun {ip}")
    except Exception as e:
        logger.error(f"Exception occurred during block_ip {e}")
        

def unblock_ip(host, ssh_user, ssh_password, ip):
    try:
        device = ftd_connection(host, ssh_user, ssh_password)
        output = device.send_command_clish(f"no shun {ip}")
        logger.info(f"{host} no shun {ip}")
    except Exception as e:
        logger.error(f"Exception occurred during block_ip {e}")
        


if __name__ == "__main__":

    try: 
        # read variables from docker compose file
        blocklist_urls = os.environ["BLOCKLIST_URLS"].split(',')
        logger.info(f"blocklist_urls: {blocklist_urls}")
        hosts = os.environ["HOSTS"].split(',')
        logger.info(f"hosts: {hosts}")
        ssh_user = os.environ["SSH_USER"]
        logger.info(f"ssh_user: {ssh_user}")
        ssh_password = os.environ["SSH_PASSWORD"]
        logger.info(f"ssh_password: {ssh_password}")
    except Exception as e:
        logger.error("Missing configuration. This script requires the following variables in your docker-compose.yml file:\n1. BLOCKLIST_URLS\n2. HOSTS\n3. SSH_USER\n4. SSH_PASSWORD")


    ips_from_nfg_blocklists = get_blocklists(blocklist_urls) # get all IPs in all specified blocklists

    for host in hosts:
        currently_blocked_ips = get_currently_blocked_ips(host, ssh_user, ssh_password) # get the currently blocked IPs on a host

        # Create the lists for shun and no shun
        ips_to_block = ips_from_nfg_blocklists - currently_blocked_ips
        ips_to_unblock = currently_blocked_ips - ips_from_nfg_blocklists
        logger.info(f"{len(ips_to_block)} IPs to shun\n{len(ips_to_unblock)} IPs to no shun")

        # shun IPs
        for ip_to_block in ips_to_block:
            block_ip(host, ssh_user, ssh_password, ip_to_block)

        # no shun IPs
        for ip_to_unblock in ips_to_unblock:
            unblock_ip(host, ssh_user, ssh_password, ip_to_unblock)

    time.sleep(300)