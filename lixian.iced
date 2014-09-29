Phantom = require './phantom'

module.exports = class Lixian extends Phantom


  init: (options, cb)->
    options.switches ?= []
    options.switches.push "--web-security=no"
    await super options, defer e
    return cb e if e
    await @page. set 'viewportSize', width: 1440, height: 1024, defer()
    return cb null

  login: (options, cb)->
    return cb new Error '`username` argument must be provided!' unless options.username
    return cb new Error '`password` argument must be provided!' unless options.password

    await @page.open 'http://lixian.xunlei.com', defer status
    await @waitForSelector '#u', defer e
    return cb e if e
    await @waitForSelector '#p_show', defer e
    return cb e if e
    await @page.evaluate (data)->
        window.restime = null
        document.querySelector '#u'
          .onfocus()
        document.querySelector '#u'
          .value = data.username
        document.querySelector '#p_show_err'
          .onfocus()
        document.querySelector '#p_show'
          .value = data.password
      , defer(),
        username: options.username
        password: options.password
    await setTimeout defer(), 2000
    await @page.evaluate (data)->
        document.querySelector '#button_submit4reg'
          .onclick()
      , defer()
    await @watchOutForVcode (data)->
        document.querySelector '#p_show'
          .value = data.password
        document.querySelector '#button_submit4reg'
          .onclick()
      , password: options.password, defer e
    return cb e if e
    await @waitForSelector '#rowbox_list', defer e
    return cb e if e

    @logon = true
    return cb null

  list: (options, cb)->
    return cb new Error 'you must login first' unless @logon
    await @execute (done)->
        $.getJSON INTERFACE_URL + "/showtask_unfresh?callback=?",
          type_id: 4
          page: 1
          tasknum: 30
          t: (new Date()).toString()
          p: 1
          interfrom: 'task'
          , (data)->
            done null, data
      , defer e, taskdata
    return cb e if e
    tasks = []
    for task in taskdata.info.tasks
      if task.tasktype == 1
        tasks.push
          name: task.taskname
          id: task.id
          files: [
            name: task.taskname
            url: task.lixian_url
          ]
      if task.tasktype == 0
        tasks.push folder =
          name: task.taskname
          files: []
          id: task.id
        await @execute task, (task, done)->
            window.__folder_data__ = null
            $.getJSON INTERFACE_URL+"/fill_bt_list?callback=?",
              tid: task.id
              infoid: task.cid
              g_net: G_section
              p: 1
              uid: G_USERID
              interfrom: G_PAGE, (data)->
                done null, data
          , defer e, folderdata
        return cb e if e
        for item in folderdata.Result[task.id]
          folder.files.push
            name: item.title
            url: item.downurl
    await @execute ((done)-> done null, document.cookie), defer e, cookie
    return cb e if e
    cb null, tasks: tasks, cookie: cookie
  add_url: (options, cb)->
    return cb new Error 'you must login first' unless @logon
    return cb new Error '`url` argument must be provided!' unless options.url


    await @page.evaluate (data)->
        add_task_new 0
        document.querySelector '#task_url'
          .value = data.url
      , defer(), url: options.url
    await @waitForSelector '#down_but:not([disabled])', defer e
    return cb e if e
    await @page.evaluate ->
        document.querySelector '#down_but'
          .onclick()
      , defer()
    await @watchOutForVcode ->
        document.querySelector '#down_but'
          .onclick()
      , null, defer()
    return cb e if e
    await @waitForExpression ->
        document.querySelector '#add_task_panel'
          .style
          .display == 'none'
      , null, defer e
    return cb e if e
    cb null

  add_torrent: (options, cb)->
    return cb new Error 'you must login first!' unless @logon
    return cb new Error '`torrent` argument must be provided!' unless options.torrent

    await @page.evaluate (data)->
        add_task_new 1
      , defer()
    @page.uploadFile '#filepath', options.torrent

    await @waitForExpression ->
        select_all = document.querySelector '#bt_edit_input_all'
        return false unless select_all.offsetParent
        select_all.setAttribute('checked', 'checked')
        select_all.onclick()
        return true
      , null, defer()
    await @waitForSelector '#down_but:not([disabled])', defer e
    return cb e if e
    await @page.evaluate ->
        document.querySelector '#down_but'
          .onclick()
      , defer()
    await @watchOutForVcode ->
        document.querySelector '#down_but'
          .onclick()
      , null, defer()
    return cb e if e
    await @waitForExpression ->
        document.querySelector '#add_task_panel'
          .style
          .display == 'none'
      , null, defer e
    return cb e if e
    cb null

  delete_task: (options, cb)->
    return cb new Error 'you must login first' unless @logon
    return cb new Error '`delete` argument must be provided!' unless options.delete

    await @execute options.delete, (id, done)->
        $.post INTERFACE_URL + "/task_delete?callback=&type=0",
          taskids: id
          databases: 0
          interfrom: 'task'
          , ->
            return done null
      , defer e
    return cb e if e
    cb null

  watchOutForVcode: (submitFun, data, cb)->
    await setTimeout defer(), 2000
    await @page.evaluate ->
        window.__vcode_img__ = document.querySelector 'img[src*="http://verify"][src*=".xunlei.com/image"]'
        window.__vcode_img__?.offsetParent
      , defer(vcode_exists)
    return cb e if e
    if vcode_exists
      await @waitForExpression ->
          return null unless window.__vcode_img__.naturalWidth && window.__vcode_img__.naturalHeight
          canvas = document.createElement 'canvas'
          canvas.width = window.__vcode_img__.naturalWidth
          canvas.height = window.__vcode_img__.naturalHeight
          canvas.getContext('2d').drawImage window.__vcode_img__, 0, 0
          return canvas.toDataURL 'image/jpeg', 0.5
        , null, defer e, vcode_data
      return cb e if e
      await @vcodeHandler vcode_data, defer e, vcode
      return cb e if e
      await @page.evaluate (data)->
          document.querySelector '#verifycode'
            .value = data.vcode
        , defer(), vcode: vcode
      await @page.evaluate submitFun, defer(), data
      await @watchOutForVcode submitFun, defer e
      return cb e if e

    return cb null
    
  vcodeHandler: (vcode_data, cb)->
    return cb new Error 'unhandled vcode'







