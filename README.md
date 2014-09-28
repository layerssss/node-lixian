node-lixian
===========

非官方迅雷离线下载服务 API for nodejs

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
  Usage: lixian [options] [command] [more commands..]

  Available commands:

  * login: log-in, options: username, password
  * list: list all tasks
  * delete_task: delete one task, options: delete
  * add_url: add a download task by url, options: url
  * add_torrent: add a bt download task by torrent file, options: torrent

  Options:

    -h, --help                output usage information
    -V, --version             output the version number
    -u --username <username>  username
    -p --password <password>  password
    -d --delete <id>          id of task to be deleted
    -U --url <url>            url
    -t --torrent <path>       torrent path
    -d --debug                add debug infomation
    -V --novcode              do not handle verification code
```

比如：添加一个任务，然后列出列表

```
lixian --username "USER@SERVER.com" --password "pAS5w0rD" --url "http://xxx.com/xx.tar.gz" login add_url list
```

# 实现原理

这个模块调用 PhantomJS 在内存中开启了一个浏览器内核，然后在登录时打开[迅雷提供的离线下载网页版](lixian.vip.xunlei.com)，然后调用该页面上暴露的接口。

# API

* `lixian.init({}, function(e){ });`
* `lixian.login({username: 'USER@SERVER.com', password: 'pAS5w0rD'}, function(e){ });`
* `lixian.list({}, function(e, list){ });`
* `lixian.delete_task({delete: '1234567'}, function(e){ });`
* `lixian.add_url({url: 'http://xxx.com/xx.tar.gz'}, function(e){ });`
* `lixian.add_torrent({torrent: 'http://xxx.com/xx.tar.gz'}, function(e){ });`
* `lixian.vcodeHandler = function(verification_code_image_data_url, cb){ cb(null/* error */, 'aFe4'/* 4-chars verification code */); };`

# 故事

[你好，node-lixian](http://micy.in/posts/2014-09-28-hello-node-lixian.html)

# 代码授权

[The MIT License (MIT)](LICENSE)
