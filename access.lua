-- 连接redis
local redis = require 'resty.redis'
local cjson = require 'cjson'
local cache = redis.new()
local ok ,err = cache.connect(cache,'127.0.0.1','6379')
local host_uri = ngx.var.host..ngx.var.uri
local ip = ngx.var.remote_addr
local return_json = '{"code":0,"message":"成功","data":{"effected":true},}'
local iconv = require("iconv")  
local togbk = iconv.new("gbk", "utf-8")  
local return_json, err = togbk:iconv(return_json)  

--白名单{"hostname/uri/":"0"}
--单位时间
local time_fm = 60
--设置临时黑名单的时间
local out_time = 60
--设置单位时间内接口次数
local connect_count = 3
cache:set_timeout(60000)
-- 如果连接失败，跳转到label处
if not ok then
  goto label
end
is_white,err = cache:get(host_uri)
is_white = tonumber(is_white)
if is_white == nil then
  is_ban,err = cache:get('ban'..host_uri..ip)
  if tonumber(is_ban) == 1 then
--    ngx.exit(ngx.HTTP_FORBIDDEN)
    ngx.say(return_json)
    ngx.exit(ngx.HTTP_OK)
  end
  
  start_time,err = cache:get('time'..host_uri..ip)
  ip_count,err = cache:get('count'..host_uri..ip)
  
  if start_time == ngx.null or os.time() - tonumber(start_time) > time_fm then
    res,err = cache:set('time'..host_uri..ip,os.time())
    res,err = cache:set('count'..host_uri..ip,1)
    goto label
  else
    ip_count = ip_count + 1
    res,err = cache:set('count'..host_uri..ip,ip_count)
    if ip_count >= connect_count then
      res,err = cache:set('ban'..host_uri..ip,1)
      res,err = cache:expire('ban'..host_uri..ip,out_time)
    end
  end
  goto label
end

--0为白名单
if is_white == 0 then
  ngx.say('white')
  goto label
end
-- 不为0为黑名单
if is_white ~= 0 then
  ngx.exit(ngx.HTTP_FORBIDDEN)
end  

goto label
::label::
local ok , err = cache:close()
