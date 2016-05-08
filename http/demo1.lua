local http = require "chttp"

data = [[GET /favicon.ico HTTP/1.1
Host: 0.0.0.0=5000
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9) Gecko/2008061015 Firefox/3.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive

]]

request = {}
ok = http.parse(request, data)

print(request.Host)
for k,v in pairs(request.Head) do
    print(k, v)
end
