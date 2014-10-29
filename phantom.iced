phantom = require 'phantom'
module.exports = class Phantom
  constructor: ->
    @timeout ?= 5000
  init: (options, cb)->
    options.weakref ?= true
    return cb null if @inited
    await phantom.create options.switches..., defer(@ph), 
      dnodeOps: 
        weak: options.weakref
    await @ph.createPage defer @page
    @inited = true
    cb null
  waitForExpression: (expression, data, cb)->
    time = @timeout
    while true
      await @page.evaluate expression, defer(result), data
      return cb null, result if result
      await setTimeout defer(), 30
      time -= 30
      return cb new Error "waiting timeout: \n#{expression.toString()}\n#{JSON.stringify data, null, '  '}" if time <= 0
  waitForSelector: (selector, cb)->
    await @waitForExpression (data)-> 
        document.querySelectorAll data.selector
          .length
      , selector: selector, defer e
    return cb new Error "waiting for selector timeout: #{selector}" if e
    cb null


  getNewId: (cb)->
    @ids ?= []
    while true
      id = "__phantom_#{Date.now()}__"
      return cb null, id if  -1 == @ids.indexOf id
      await setTimeout defer(), 10
  execute: (inputs..., fn, cb)->
    await @getNewId defer e, results_id
    await @page.evaluate (data)->
        window[data.results_id] = null
        window.__slice = [].slice
        __func = null
        eval '__func = ' + data.fn
        __func data.inputs..., (e, outputs...)->
          window[data.results_id] =
            error: e
            outputs: outputs
      , defer(), 
        fn: fn.toString()
        inputs: inputs
        results_id: results_id
    await @waitForExpression (data)->
        window[data.results_id]
      , results_id: results_id, defer e, results
    return cb e if e
    if results.error
      return cb results.error
    return cb null, results.outputs...
