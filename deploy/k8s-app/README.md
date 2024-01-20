
# Output

## Socks5 Proxy

| Hostname | IP |
| :---: | :---: |
| ip.divecode.in | 52.177.151.92 |
| socks5.divecode.in | 20.10.123.100 |
| agic.divecode.in | 4.152.48.150 |

### ipconfig.me

#### With Socks5

```bash
$ curl --socks5 socks5.divecode.in:1080 -U pichuang:pichuang http://ifconfig.me/all -vvv
*   Trying 20.10.123.100:1080...
* SOCKS5 connect to IPv4 34.117.118.44:80 (locally resolved)
* SOCKS5 request granted.
* Connected to socks5.divecode.in (20.10.123.100) port 1080 (#0)
> GET /all HTTP/1.1
> Host: ifconfig.me
> User-Agent: curl/7.76.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< server: fasthttp
< date: Sat, 13 Jan 2024 13:37:49 GMT
< content-type: text/plain
< Content-Length: 225
< access-control-allow-origin: *
< via: 1.1 google
<
ip_addr: 20.22.48.77
remote_host: unavailable
user_agent: curl/7.76.1
port: 42166
language:
referer:
connection:
keep_alive:
method: GET
encoding:
mime: */*
charset:
via: 1.1 google
forwarded: 20.22.48.77,34.117.118.44
* Connection #0 to host socks5.divecode.in left intact
```

#### Without Socks5

```bash
$ curl http://ifconfig.me/all -vvv
*   Trying 34.117.118.44:80...
* Connected to ifconfig.me (34.117.118.44) port 80 (#0)
> GET /all HTTP/1.1
> Host: ifconfig.me
> User-Agent: curl/7.76.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< server: fasthttp
< date: Sat, 13 Jan 2024 13:38:47 GMT
< content-type: text/plain
< Content-Length: 227
< access-control-allow-origin: *
< via: 1.1 google
<
ip_addr: 20.96.89.119
remote_host: unavailable
user_agent: curl/7.76.1
port: 38050
language:
referer:
connection:
keep_alive:
method: GET
encoding:
mime: */*
charset:
via: 1.1 google
forwarded: 20.96.89.119,34.117.118.44
* Connection #0 to host ifconfig.me left intact
```

### ip.divecode.in

#### With Socks5

```bash
$ curl --socks5 socks5.divecode.in:1080 -U pichuang:pichuang http://ip.divecode.in/all -vvv
*   Trying 20.10.123.100:1080...
* SOCKS5 connect to IPv4 20.10.235.247:80 (locally resolved)
* SOCKS5 request granted.
* Connected to socks5.divecode.in (20.10.123.100) port 1080 (#0)
> GET /all HTTP/1.1
> Host: ip.divecode.in
> User-Agent: curl/7.76.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Content-Type: text/plain; charset=utf-8
< Date: Sat, 13 Jan 2024 13:41:37 GMT
< Content-Length: 181
<
country_code: ""
encoding: ""
forwarded: ""
host: 10.67.0.5
ifconfig_hostname: ip.divecode.in
ip: 10.67.0.5
lang: ""
method: GET
mime: '*/*'
port: 16255
referer: ""
ua: curl/7.76.1
* Connection #0 to host socks5.divecode.in left intact
```

#### Without Socks5

```bash
$ curl http://ip.divecode.in/all -vvv
*   Trying 20.10.235.247:80...
* Connected to ip.divecode.in (20.10.235.247) port 80 (#0)
> GET /all HTTP/1.1
> Host: ip.divecode.in
> User-Agent: curl/7.76.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Content-Type: text/plain; charset=utf-8
< Date: Sat, 13 Jan 2024 13:42:00 GMT
< Content-Length: 181
<
country_code: ""
encoding: ""
forwarded: ""
host: 10.67.0.5
ifconfig_hostname: ip.divecode.in
ip: 10.67.0.5
lang: ""
method: GET
mime: '*/*'
port: 24650
referer: ""
ua: curl/7.76.1
* Connection #0 to host ip.divecode.in left intact
```
