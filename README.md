node-lixian
===========

非官方迅雷离线下载服务 API for nodejs，全部使用 JavaScript 编写，移植自 [使用 python 编写的 xunlei-lixian 脚本](https://github.com/iambus/xunlei-lixian)。

# 安装和使用

```
npm install node-lixian --save
```

```
var Lixian = require('node-lixian');
var lixian = new Lixian();

lixian.init({}, function(e){
  if(e) return;

  lixian.login({
    username: 'USER@SERVER.com',
    password: 'pAS5w0rD'
  }, function(e){
    if(e) return;

    lixian.list({}, function(e, list){
      if(e) return;

      console.log(list);      
    });
  })
});
```

# 通过命令行调用

```
  Usage: lixian [选项] [命令] [更多命令..]

  命令按顺序执行，所有的命令有：

  * login: 登录, 选项: username, password / hashed_password
  * list: 列出所有任务
  * delete_task: 删除单个任务, options: id
  * add_url: 增加一个下载任务, options: url
  * add_torrent: 通过种子文件增加一个下载任务, options: torrent

  Options:

    -h, --help                              output usage information
    -V, --version                           output the version number
    -u --username <username>                用户名
    -p --password <password>                密码
    -P --hashed-password <hashed-password>  md5(md5(密码))
    -c --cookie-path <path>                 用于储存和读取 Cookie 的 JSON 文件
    -d --delete <id>                        要删除的任务的 id
    -U --url <url>                          要增加的任务的 URL
    -t --torrent <path>                     要增加的 BT 种子
    -D --debug                              输出大量的调试信息
    -V --novcode                            不要让我在命令行输入验证码
```

比如：添加一个任务，然后列出列表

```
lixian --username "USER@SERVER.com" --password "pAS5w0rD" --url "http://xxx.com/xx.tar.gz" login add_url list
```

# API

* `lixian.init({ cookie: JSON.parse(fs.readFileSync('cookies.json')) }, function(e){ });`
* `lixian.logon; /* true or false */`
* `lixian.dumpCookie(); /* Object */`
* `lixian.login({username: 'USER@SERVER.com', password: 'pAS5w0rD'}, function(e){ });`
* `lixian.list({}, function(e, list){ });`
* `lixian.delete_task({delete: '1234567'}, function(e){ });`
* `lixian.add_url({url: 'http://xxx.com/xx.tar.gz'}, function(e){ });`
* `lixian.add_torrent({torrent: 'http://xxx.com/xx.tar.gz'}, function(e){ });`
* `lixian.vcodeHandler = function(verification_code_image_data_url, cb){ cb(null/* error */, 'aFe4'/* 4-chars verification code */); };`

# 代码授权

[The MIT License (MIT)](LICENSE)
