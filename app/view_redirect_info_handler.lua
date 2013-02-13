-- functions definitions
--
local gmatch        = string.gmatch

-- Param definitions
--
local uri           = ngx.var.uri
local virtualhost   = ngx.req.get_headers()['Host']

-- Local functions
--
function tabletostr(s)
    local t = { }
    for k,v in pairs(s) do
        t[#t+1] = k .. ':' .. v
    end
    return table.concat(t,'|')
end

function buildURL(domain, key, role, keyEdit)
    local temporalURL = 'http://' .. domain  
    if role then 
        temporalURL = temporalURL .. '/' .. role 
    end ; temporalURL = temporalURL .. '/' .. key ; 
    if keyEdit then 
        temporalURL = temporalURL .. '/' .. keyEdit
    end
    return temporalURL
end

-- Initiate GET /view validator
--
ngx.header.content_type = 'text/html';

for k, e in gmatch(uri, '/view/([a-z0-9A-Z]+)/([a-z0-9A-Z]+)$') do
    key     = k
    keyEdit = e
    ngx.log(ngx.ERR, "key is: " .. key .. " | Edit key is: " .. keyEdit)
end

if keyEdit == nil then
    -- Since lua lacks POSIX regex, we have to go by two pattern matching.
    -- So if !keyEdit -> launch another pattern matching to get 'key'  
    for k, e in gmatch(uri, '/view/([a-z0-9A-Z]+)$') do
        key     = k
        ngx.log(ngx.ERR, "key is: " .. key)
    end
end

if key == nil then
    -- It's not a valid Shorten View Resource key, die now biatch
    ngx.status = ngx.HTTP_GONE
    ngx.say(uri, ': You provided an invalid redirection (target mismatch).')
    ngx.log(ngx.ERR, 'Resource was not an HTTP link (http nor https). Resource provided: ', uri)
    ngx.exit(ngx.HTTP_OK)
end

-- Initialize redis
--
local redis = require 'resty.redis'
local red = redis:new()
red:set_timeout(100)  -- in miliseconds

local ok, err = red:connect('127.0.0.1', 6379)
if not ok then
    ngx.log(ngx.ERR, 'failed to connect: ', err)
    return
end

-- Main process
--
local res, err = red:hget(key, 'host')
if not res then
    ngx.log(ngx.ERR, 'failed to get: ', res, err)
    return
end

if  res == ngx.null or type(res) == null then
    ngx.log(ngx.ERR, 'failed to get redirection for key: ', key)
    return ngx.redirect('https://duckduckgo.com/?q=Looking+For+Something?', ngx.HTTP_MOVED_TEMPORARILY)
else
    red:hset(key, 'atime', os.time()) 
    red:hincrby(key, 'requested', 1)
    ngx.header['X-DT-Redirect-ctime'] = red:hget(key, 'ctime')
    ngx.header['X-DT-Redirect-Requested'] = red:hget(key, 'requested')
     
    ngx.say('<html><head><title>Shortened URL Service</title></head><body bgcolor=white><center><h1>Your Shortened URL is</h1><h2><a href="http://localhost/' .. key .. '">http://localhost/' .. key .. '</a></h2><h2>Your Shortened URL service points to</h2><h2><h2><a href=' .. res .. '>' .. res .. '</a>')
    if keyEdit ~= nil then
        eURL = buildURL(virtualhost, key, 'edit', keyEdit)
        ngx.say('<hr><center><h3>You Can Edit Your Shortened URL Using</h3><h3><a href="' .. eURL .. '">' .. eURL .. '</a></h3></center></body></html>')
    end
end
