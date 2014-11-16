request = require 'request'
vm = require 'vm'
fs = require 'fs'
path = require 'path'
md5 = require 'MD5'
jarson = require 'jarson'

module.exports = class Lixian 
  headers: 
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36'
    'Accept': 'text/html'
    'Accept-Language': 'zh-CN,zh;q=0.8,en-US;q=0.2,en;q=0.2'

  init: (options, cb)->
    @_debug = options.debug
    @_jar = request.jar()
    if options.cookie
      @_jar._jar = jarson.fromJSON options.cookie

    await @_reload defer e
    return cb e if e

    return cb null

  _get_binary: (url, qs, cb)->
    url += "?"
    url += "#{encodeURIComponent k}=#{encodeURIComponent v}&" for k, v of qs
    req = 
      method: 'GET'
      url: url
    await @_request req, defer e, body
    return cb e if e

    return cb null, body

  _get: (url, qs, cb)->
    await @_get_binary url, qs, defer e, body
    return cb e if e

    body = body.toString 'utf8'
    @debug 'response.body', body
    return cb null, body

  debug: (prefix, data)->
    return unless @_debug
    data = JSON.stringify data, null, ' ' unless data?.constructor is String
    if (lines = data.split '\n').length > 30
      console.log "#{prefix}> #{line}" for line in lines[..30]
      console.log "#{prefix}>   ... total: #{lines.length} lines ..."
    else
      console.log data.replace /^/mg, "#{prefix}> "

  _post: (url, qs, data, cb)->
    url += "?"
    url += "#{encodeURIComponent k}=#{encodeURIComponent v}&" for k, v of qs
    req = 
      method: 'POST'
      url: url
      encoding: 'utf8'
    multipart = false
    for key, field of data
      if !field?
        delete data[key] 
      else
        if field.constructor is Object
          multipart = true 
          if field.value.constructor is Buffer
            field.value.toJSON = -> "Buffer(#{@length})"
        
    if multipart
      req.formData = data
    else
      req.form = data
    await @_request req, defer e, body
    @debug 'response.body', body
    return cb e if e

    return cb null, body

  _request: (req, cb)->
    req.encoding ?= null
    req.headers ?= @headers

    @debug 'request', req

    req.jar ?= @_jar
    
    req = request req, (e, res, body)=>
      @debug 'response.headers', res.headers if res?.headers?
      cb e, body
    @debug 'request.headers', req.headers


  _md5: (string)-> md5 string 

  _cookie: (key, cb)->
    await @_jar._jar.getCookies 'http://lixian.vip.xunlei.com/task.html', defer e, cookies
    return cb e if e

    for cookie in cookies
      if cookie.key == key
        return cb null, cookie.value

    return cb null, null

  _jsonp: (url, callback_fn, qs, data, cb)->
    qs.callback = callback_fn
    if data?
      await @_post url, qs, data, defer e, data
      return cb e if e
    else
      await @_get url, qs, defer e, data
      return cb e if e
    if alert = data.match /alert\(\'([^\']+\')/
      return cb new Error alert[1]

    sandbox = {
      data: null
    }
    try
      vm.runInNewContext "var #{callback_fn} = function(){ data = arguments; }; #{data}", sandbox, 'node-lixian.jsonp.vm'
    catch e
      return cb e
    data = sandbox.data
    return cb new Error "发生未知错误" unless data?.length?
    cb null, data...

  dumpCookie: ->
    jarson.toJSON @_jar._jar

  login: (options, cb)->
    return cb new Error '`username` 参数必须提供!' unless options.username
    return cb new Error '`password` 或者 `hashed_password` 参数必须提供!' unless options.password || options.hashed_password

    await @_reload defer e
    return cb e if e

    @logon = false
    timespan = Date.now() / 1000
    await @_get "http://login.xunlei.com/check",
      u: @_userid
      cachetime: timespan
    , defer e, body
    return cb e if e

    await @_cookie 'check_result', defer e, cookie
    return cb e if e
    
    vcode = cookie[2..]

    unless vcode
      await @_get_binary "http://verify2.xunlei.com/image", cachetime: timespan, defer e, body
      return cb e if e
      await @vcodeHandler body, defer e, vcode
      return cb e if e

    await @_post "http://login.xunlei.com/sec2login/", {},
      u: options.username, 
      p: @_md5 "#{options.hashed_password || @_md5 @_md5 options.password}#{vcode.toUpperCase()}"
      login_enable: 1
      login_hour: 720
      verifycode: vcode
      business_type: 108
    , defer e, body
    return cb e if e

    await @_cookie 'userid', defer e, @_userid
    return cb e if e
    return cb new Error '登录失败' unless @_userid

    await @_get "http://dynamic.lixian.vip.xunlei.com/login",
      cachetime: timespan
      from: 0
    , defer e, body
    return cb e if e
    return cb new Error '登录失败' unless body.length >= 512

    

    @logon = true
    return cb null

  _reload: (cb)->
    await @_cookie 'userid', defer e, @_userid
    return cb if e

    unless @_userid
      @logon = false
      return cb null

    timespan = Date.now() / 1000
    await @_get "http://dynamic.cloud.vip.xunlei.com/user_task",
      userid: @_userid
      st: 4
      t: timespan
    , defer e, body
    return cb e if e

    @logon = body.length >= 512

    await @_cookie 'userid', defer e, @_userid
    return cb if e

    cb null

  list: (options, cb)->
    await @_reload defer e
    return cb e if e

    return cb new Error '必须重新登录' unless @logon

    page = 1
    taskdata = []
    while true
      await @_jsonp "http://dynamic.cloud.vip.xunlei.com/interface/showtask_unfresh", "jsonp#{Date.now()}",
        type_id: 4
        page: page
        tasknum: 30
        t: (new Date()).toString()
        p: page
        interfrom: 'task'
        , null, defer e, data
      return cb e if e
      break unless data.info.tasks.length
      taskdata.push task for task in data.info.tasks
      @_jar.setCookie "gdriveid=#{data['info']['user']['cookie']}; expire=#{new Date(Number(Date.now()) + 3600000 * 24).toUTCString()}; path=/; domain=.vip.xunlei.com;", 'http://dynamic.cloud.vip.xunlei.com/interface/showtask_unfresh'
      page += 1
    tasks = []
    for task in taskdata
      if task.tasktype == 1
        tasks.push
          name: task.taskname
          id: task.id
          files: [
            name: task.taskname
            url: task.lixian_url
            size: Number task.file_size
            md5: task.verify
          ]
      if task.tasktype == 0
        tasks.push folder =
          name: task.taskname
          files: []
          id: task.id

        folderdata = []
        page = 1
        while true
          await @_jsonp "http://dynamic.cloud.vip.xunlei.com/interface/fill_bt_list", 'fill_bt_list',
            tid: task.id
            infoid: task.cid
            g_net: 1
            p: page
            uid: @_userid
            interfrom: 'task'
            , null, defer e, data
          return cb e if e
          break unless data.Result.Record.length
          folderdata.push file for file in data.Result.Record
          page += 1

        for item in folderdata
          folder.files.push
            name: item.title
            url: item.downurl
            size: Number item.filesize
            md5: item.verify
    cookie = @_jar.getCookieString 'http://dynamic.cloud.vip.xunlei.com/'

    return cb e if e
    cb null, tasks: tasks, cookie: cookie
  add_url: (options, cb)->
    return cb new Error '`url` 参数必须提供!' unless options.url

    await @_reload defer e
    return cb e if e

    return cb new Error '必须重新登录' unless @logon
    

    timespan = Date.now() / 1000
    random = Math.floor Math.random() * 1000

    if options.url.match /^magnet\:/
      await @_jsonp "http://dynamic.cloud.vip.xunlei.com/interface/url_query", 'queryUrl',
        u: options.url
        random: timespan
      , null, defer e, ret_code, cid, tsize, btname, d, filename_arr, filesize_arr, format_arr, index_arr
      return cb e if e
      return new Error '任务信息查找失败' unless 1 == Number ret_code

      await @_commit_task "http://dynamic.cloud.vip.xunlei.com/interface/bt_task_commit", 
        callback: "jsonp#{Date.now()}",
        t: timespan
      , 
        uid: @_userid
        btname: btname
        cid: cid
        goldbean: 0
        silverbean: 0
        tsize: tsize
        findex: index_arr.map((s)-> "#{s}_").join ''
        size: filesize_arr.map((s)-> "#{s}_").join ''
        o_taskid: 0
        o_page: 'task'
        class_id: 0
        interfrom: 'task'
      , (data)->
        Number data.progress
      , defer e, data
      return cb e if e

    else
      await @_jsonp "http://dynamic.cloud.vip.xunlei.com/interface/task_check", "queryCid",
        url: options.url
        random: random
        tcache: timespan
      , null, defer e, cid, gcid, size_required, d, filename, goldbean_need, silverbean_need, is_full
      return cb e if e

      task_type = 0
      if options.url.match /^ed2k\:/
        task_type = 2

      await @_commit_task 'http://dynamic.cloud.vip.xunlei.com/interface/task_commit', 'ret_task',
        uid: @_userid
        cid: cid
        gcid: gcid
        size: size_required
        goldbean: goldbean_need
        silverbean: silverbean_need
        t: filename
        url: options.url
        type: task_type
        o_page: 'task'
        o_taskid: '0'
      , null, (ret_code)->
        Number ret_code
      , defer e
      return cb e if e

    cb null

  _commit_task: (url, callback_fn, qs, data, fn_ret_code, cb)->
    timespan = Date.now() / 1000

    await @_jsonp url, callback_fn, qs, data, defer e, data...
    return cb e if e

    ret_code = fn_ret_code data...

    return cb null, data... unless ret_code in [-12, -11]

    await @_get_binary "http://verify2.xunlei.com/image", t: 'MVA', cachetime: timespan, defer e, body
    return cb e if e
    await @vcodeHandler body, defer e, vcode
    return cb e if e 

    data['verify_code'] = vcode

    await @_jsonp url, callback_fn, qs, data, defer e, data...
    return cb e if e

    ret_code = fn_ret_code data...

    return cb new Error '验证码错误' if ret_code in [-12, -11]
    return cb null, data...

  add_torrent: (options, cb)->
    return cb new Error '`torrent` 参数必须提供!' unless options.torrent

    await @_reload defer e
    return cb e if e

    return cb new Error '必须重新登录!' unless @logon

    timespan = Date.now() / 1000

    await fs.readFile options.torrent, defer e, torrent
    return cb e if e

    await @_post "http://dynamic.cloud.vip.xunlei.com/interface/torrent_upload", 
      random: timespan
      interfrom: 'task'
    , 
      filepath: 
        value: torrent
        options: 
          filename: path.basename options.torrent
          contentType: 'application/octet-stream'
    , defer e, data
    return cb e if e

    sandbox = {
      document: {}
      error: null
      btResult: null
    }
    data = data.replace /\<\/?script\>/g, ''
    try
      vm.runInNewContext "var alert = function(){ error = arguments[0]; };#{data}", sandbox
    catch e
      return cb e 
    return cb new Error String sandbox.error if sandbox.error
    return cb new Error "发生未知错误" unless data = sandbox.btResult

    await @_commit_task "http://dynamic.cloud.vip.xunlei.com/interface/bt_task_commit", "jsonp#{Date.now()}",
      t: timespan
    , 
      uid: @_userid
      btname: data.ftitle
      cid: data.infoid
      goldbean: 0
      silverbean: 0
      tsize: data.btsize
      findex: data.filelist.map((s)-> "#{s.id}_").join ''
      size: data.filelist.map((s)-> "#{s.subsize}_").join ''
      o_taskid: 0
      o_page: 'task'
      class_id: 0
      interfrom: 'task'
    , (data)->
        Number data.progress
    , defer e, data
    return cb e if e

    cb null

  delete_task: (options, cb)->
    return cb new Error '`delete` 参数必须提供!' unless id = options.delete
    
    await @_reload defer e
    return cb e if e

    return cb new Error '必须重新登录' unless @logon

    timespan = Date.now() / 1000

    await @_jsonp "http://dynamic.cloud.vip.xunlei.com/interface/task_delete", "jsonp#{Date.now()}",
      type: 2
      noCacheIE: timespan
    ,
      taskids: id
      databases: 0
      interfrom: 'task'
    , defer e, data
    return cb e if e
    cb null
    
  vcodeHandler: (vcode_data, cb)->
    return cb new Error 'unhandled vcode'









