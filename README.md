# shadowsocks-poseidon
Shadowsocks 单端口多用户，适配多种面板

[Documentation](https://github.com/ColetteContreras/ssp/wiki)

### Install

```
(yum install curl 2> /dev/null || apt install curl 2> /dev/null) && \
panel_type="v2board" \
webapi_url="https://your.webapi.host" \
webapi_key="YOUR_NODE_KEY" \
node_id=1 \
poseidon_license="" \
bash <(curl -L https://bit.ly/3jyAijB)
```

### Commands

| Function | command | 
|------------|--------|
| Show logs  | `journalctl -n 100 -f --no-pager -u ssp` |
| Show status  | `systemctl status ssp` |
| Stop  | `systemctl stop ssp` |
| Start  | `systemctl start ssp` |
| Restart  | `systemctl restart ssp` |
| Upgrade | `bash <(curl -L https://bit.ly/3jyAijB)` |
| Uninstall | `bash <(curl -L https://bit.ly/33wXh9j)` |
