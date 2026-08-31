# AWS EC2 Setup Guide: Kisan CattleVision Relay Server

This guide walks you through launching and configuring an AWS EC2 instance to host the public relay server.

---

## 🛠️ Step 1: Launch the EC2 Instance in AWS Console

1. Log into the [AWS Management Console](https://console.aws.amazon.com/).
2. Navigate to the **EC2 Dashboard** and click **Launch Instance**.
3. Configure the following fields:
   * **Name**: `Kisan-CattleVision-Relay`
   * **Application and OS Image (AMI)**: Select **Ubuntu** (Ubuntu Server 22.04 LTS or 24.04 LTS, 64-bit x86).
   * **Instance Type**: Select **`t2.micro`** or **`t3.micro`** (free-tier eligible).
   * **Key Pair**: Click **Create new key pair** (or select an existing one).
     * Key pair name: `kisan-relay-key`
     * Private key file format: `.pem` (for SSH via Terminal)
     * Save the downloaded `.pem` file safely on your laptop.

---

## 🔒 Step 2: Configure Security Groups (Firewall)

To allow the Jetson and mobile phone to talk to your EC2 instance, you must open ports:

1. Under **Network settings**, check:
   * [x] Allow SSH traffic from (Select **My IP** for security, or **Anywhere** if you move around).
2. Click **Launch instance** to start the machine.
3. Once launched, click on the **Instance ID** to view details.
4. Go to the **Security** tab at the bottom, and click on your **Security Group** (e.g., `launch-wizard-1`).
5. Click **Edit inbound rules** and add the following rule:
   * **Type**: `Custom TCP`
   * **Port Range**: `8080`
   * **Source**: `Anywhere-IPv4` (`0.0.0.0/0`)
   * **Description**: `Kisan Relay Port`
6. Click **Save rules**.

---

## 📌 Step 3: Allocate an Elastic IP (Highly Recommended)
*By default, EC2 IP addresses change every time you restart the instance. An Elastic IP gives you a permanent IP address.*

1. In the left-hand menu under **Network & Security**, click **Elastic IPs**.
2. Click **Allocate Elastic IP address** and click **Allocate**.
3. Select your newly allocated IP from the list, click **Actions**, and select **Associate Elastic IP address**.
4. Select your `Kisan-CattleVision-Relay` instance, and click **Associate**.
5. Note this IP address (e.g., `54.210.12.34`). This is your permanent `<YOUR-EC2-PUBLIC-IP>`.

---

## 💻 Step 4: Connect to EC2 and Deploy the Code

1. On your laptop/development computer, open a terminal in the folder where your downloaded `kisan-relay-key.pem` is stored.
2. Secure the key permissions:
   ```bash
   chmod 400 kisan-relay-key.pem
   ```
3. SSH into the instance:
   ```bash
   ssh -i "kisan-relay-key.pem" ubuntu@<YOUR-EC2-PUBLIC-IP>
   ```
4. Update the instance and install Python tools:
   ```bash
   sudo apt-get update -y
   sudo apt-get install -y python3-pip python3-venv git
   ```

---

## 📂 Step 5: Transfer the Server Code to EC2

You can transfer the `ec2_server/` directory from your Jetson or local machine to EC2 using `scp`. 

On your local machine (where the `Kisan_Jetson_Mobile/` directory is located), run:
```bash
scp -i "path/to/kisan-relay-key.pem" -r /home/mr/Documents/Deployment/Kisan_Jetson_Mobile/ec2_server ubuntu@<YOUR-EC2-PUBLIC-IP>:/home/ubuntu/
```

---

## 🔄 Step 6: Configure EC2 to Run Automatically (Systemd Service)
*This keeps the server running 24/7 in the background, restarting automatically if the EC2 instance reboots or if the script crashes.*

1. On the EC2 terminal, create a new service configuration:
   ```bash
   sudo nano /etc/systemd/system/kisan-relay.service
   ```
2. Paste the following configuration:
   ```ini
   [Unit]
   Description=Kisan CattleVision Relay Server Daemon
   After=network.target

   [Service]
   User=ubuntu
   WorkingDirectory=/home/ubuntu/ec2_server
   ExecStart=/usr/bin/python3 app.py
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```
3. Save and close (`Ctrl+O`, then `Enter`, then `Ctrl+X`).
4. Install python dependencies on EC2 globally or run setup:
   ```bash
   cd /home/ubuntu/ec2_server
   pip3 install -r requirements.txt
   ```
5. Enable and start the systemd daemon:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable kisan-relay
   sudo systemctl start kisan-relay
   ```
6. Check status to ensure it's running:
   ```bash
   sudo systemctl status kisan-relay
   ```

Now, the EC2 server is fully online and ready! You can proceed to configure the Jetson's `forwarder_config.json` with this public IP address.
