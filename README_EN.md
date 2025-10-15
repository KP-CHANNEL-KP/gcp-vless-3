---

<h1 align="center">🚀 KP CHANNEL CloudRun</h1>
<h3 align="center">✨ Multi One-Click Deploy | Auto Telegram | 4 Protocols on CloudRun ✨</h3>
<p align="center">
  🇲🇲 <a href="README.md">Myanmar ဘာသာဖြင့်ဖတ်ရန် </a> 
</p>
---

## 📦 Overview

**N4 CloudRun** is a **Bash-based auto-deployment tool** that lets you deploy  
**VLESS / Trojan / VMess** protocols on **Google Cloud Run** with a single click.  

> 🎯 Designed primarily for **Qwiklabs Users** who generate Cloud Run Keys,  
> but it also works perfectly with your **own GCP account**.

---

## 🧩 Features

- ⚙️ **Auto-Enable APIs** — *(Cloud Run + Cloud Build)*  
- 🌍 **Multi-Region Support** — 🇺🇸 🇸🇬 🇹🇼 🇯🇵  
- 🧠 **CPU / RAM Selector** — *(1vCPU → 4vCPU)*  
- 🔗 **Canonical Hostname Generator**  
- ⏱️ **Fixed Timeout (3600s)** + *5-Hour Expiry Window*  
- 📨 **Telegram `<pre><code>` Output** — with 🚀 keys only  
- 🧭 **Path Compatibility** (matching the default server config):
  - `grpc-kpchannel-cloudrun`
  - `/ws-kpchannel-cloudrun`
  - `trojan-kpchannel-grpc`
  - `/kpchannel-vmess-ws`

---

## ⚡️ One-Click Command

Run this directly inside **Google Cloud Shell** 👇

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KP-CHANNEL-KP/gcp-vless-3/main/kp.sh)

```
(or using wget)

```bash
bash <(wget -qO- https://raw.githubusercontent.com/KP-CHANNEL-KP/gcp-vless-3/main/kp.sh)

```
---

🤖 Telegram Integration (Optional)

If you want your deployment results sent automatically to your Telegram Bot,
add your token and chat ID inline like this 👇
```bash
TELEGRAM_TOKEN="123456:ABC..." TELEGRAM_CHAT_ID="123456789" \
bash <(curl -fsSL https://raw.githubusercontent.com/KP-CHANNEL-KP/gcp-vless-3/main/kp.sh)

```
---
 Alternatively, if you don’t specify them inline,
the script will ask for your Telegram Token & Chat ID during setup.
📩 Make sure your bot is started — results will be sent automatically once deployment completes.



---
 📤 Telegram Output Format

>Your Telegram bot will send a message containing
Service Info + 4 Protocol URLs (🚀) — all in Copy-Ready ``` <pre><code> ```format, optimized for sharing.
---


 Example Output

> 📦 Service Info
>🏷️ Service : kp channel
>🗺️ Region  : 🇺🇸 Iowa (us-central1)
>🧮 CPU/RAM : 2 vCPU / 4Gi
>🕒 Start   : 2025-10-11 01:30 AM
>⏳ Expire  : 2025-10-11 06:30 AM
>🔗 URL     : https://kpchannel-xxxxxxxx.us-central1.run.app

>🚀 VLESS gRPC
vless://UUID@...#%2FKP-CHANNELgRPC

>🚀 VLESS WS
vless://UUID@...#%2FKP-CHANNELWS

>🚀 TROJAN gRPC
trojan://pass@...#%2FKP-CHANNELgRPC

>🚀 VMESS WS
vmess://base64...

---

### ❤️ Support & Join Telegram

🌐 [KP CHANNEL Official](https://t.me/KP_CHANNEL_KP)  
💬 [KP GROUP](https://t.me/KP_GROUP_KP)  


⭐ Star this repo if you love the project —
your support keeps the KP ecosystem growing stronger!


---

<p align="center">© 2025 KP VPN — Built with 💙 for CloudRun Automation</p>

---
