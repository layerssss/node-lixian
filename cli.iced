commander = require 'commander'
readline = require 'readline'
fs = require 'fs'
Lixian = require './lixian'

module.exports = class Cli
  constructor: ->
  vcodeHandler: (vcode_data, cb)->
    rl = readline.createInterface
      input: process.stdin
      output: process.stdout
    console.log '需要输入验证码，请打开浏览器然后键入以下地址: '
    console.log ''
    console.log "  data:image/jpeg;base64,#{vcode_data.toString 'base64'}"
    console.log ''
    await rl.question "然后在此键入您在浏览器中看到的字符: \n:", defer answer
    cb null, answer
  run: (cb)->
    commander
      .version require('./package').version
      .usage """
      [选项] [命令] [更多命令..]

        命令按顺序执行，所有的命令有：

        * login: 登录, 选项: username, password / hashed_password
        * list: 列出所有任务
        * delete_task: 删除单个任务, options: id
        * add_url: 增加一个下载任务, options: url
        * add_torrent: 通过种子文件增加一个下载任务, options: torrent
      """
      .option '-u --username <username>', '用户名'
      .option '-p --password <password>', '密码'
      .option '-P --hashed-password <hashed-password>', 'md5(md5(密码))'
      .option '-c --cookie-path <path>', '用于储存和读取 Cookie 的 JSON 文件'
      .option '-d --delete <id>', '要删除的任务的 id'
      .option '-U --url <url>', '要增加的任务的 URL'
      .option '-t --torrent <path>', '要增加的 BT 种子'
      .option '-D --debug', '输出大量的调试信息'
      .option '-V --novcode', '不要让我在命令行输入验证码'
    commander.parse process.argv

    if commander.cookiePath
      await fs.readFile commander.cookiePath, 'utf8', defer e, commander.cookie
      try
        commander.cookie = JSON.parse commander.cookie

    lixian = new Lixian()
    await lixian.init commander, defer e
    return cb e if e
    console.log "已登录。" if lixian.logon
    lixian.vcodeHandler = @vcodeHandler unless commander.novcode
    for arg in commander.args
      process.stdout.write "操作 #{arg} 开始.."
      timer = setInterval (-> process.stdout.write '.'), 500 unless commander.debug
      console.log '' if commander.debug
      await lixian[arg] commander, defer e, data1, data2
      clearInterval timer unless commander.debug
      if e
        return cb e
      console.log "完成."
      console.log JSON.stringify data1, null, '  ' if data1?
      console.log JSON.stringify data2, null, '  ' if data2?
      if commander.cookiePath
        await fs.writeFile commander.cookiePath, JSON.stringify(lixian.dumpCookie()), 'utf8', defer e
        return cb e if e
    cb null

