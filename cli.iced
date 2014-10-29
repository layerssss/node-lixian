commander = require 'commander'
readline = require 'readline'
Lixian = require './lixian'

module.exports = class Cli
  constructor: ->
  vcodeHandler: (vcode_data, cb)->
    rl = readline.createInterface
      input: process.stdin
      output: process.stdout
    console.log 'Please open your browser and navigate to the following uri: '
    console.log ''
    console.log "  #{vcode_data}"
    console.log ''
    await rl.question "Please write down the charecters you saw: ", defer answer
    cb null, answer
  run: (cb)->
    commander
      .version require('./package').version
      .usage """
      [options] [command] [more commands..]

        Commands are executed sequentially. Available commands are:

        * login: log-in, options: username, password
        * list: list all tasks
        * delete_task: delete one task, options: id
        * add_url: add a download task by url, options: url
        * add_torrent: add a bt download task by torrent file, options: torrent
      """
      .option '-u --username <username>', 'username'
      .option '-p --password <password>', 'password'
      .option '-d --delete <id>', 'id of task to be deleted'
      .option '-U --url <url>', 'url'
      .option '-t --torrent <path>', 'torrent path'
      .option '-D --debug', 'add debug infomation'
      .option '-V --novcode', 'do not handle verification code'
    commander.parse process.argv
    lixian = new Lixian()
    await lixian.init commander, defer e
    return cb e if e
    unless commander.args.length
      commander.help()
      return
    lixian.vcodeHandler = @vcodeHandler unless commander.novcode
    for arg in commander.args
      process.stdout.write "#{arg} started.."
      timer = setInterval (-> process.stdout.write '.'), 500
      await lixian[arg] commander, defer e, data1, data2
      clearInterval timer
      if e
        await lixian.page.render 'node-lixian.error.png', defer() if commander.debug
        return cb e 
      console.log "done."
      console.log JSON.stringify data1, null, '  ' if data1?
      console.log JSON.stringify data2, null, '  ' if data2?
    cb null

