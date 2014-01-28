# Little hack to recall ourselves when
# $(document).ready() executes. One less
# level of indentation is always good!
rootob = this
rootfn = arguments.callee
firstp = arguments[0] != 'jq'
return ($ -> rootfn.call(rootob, 'jq')) if firstp

class StoreC
  @defaults =
    tests: '{}'

  get: (k) ->
    JSON.parse(
      localStorage.getItem(k) or
      defaults[k] or
      'null')
  
  set: (k, v) -> localStorage.setItem(k, JSON.stringify(v))
  
  push: (k, v, u = false) ->
    val = @get k
    
    if u
      val[v] = u
    else
      val.push(v)
    
    @set k, val

@Store = new StoreC

$('button.add').click ->
  $cases = $('.case')
  $newca = $cases.first().clone()
  $textc = $('textarea', $newca)
  $textc.val('')
  $cases.last().after($newca)
  $textc.focus()

@T =
  get: (id, cb) ->
    $.ajax
      method: 'GET'
      url: '/api/test'
      data: {id: id}
      dataType: 'json'
      complete: (res) ->
        jso = res.responseJSON
        return console.error(res) unless jso
        return console.error(jso.error, @) if jso.error
        cb(jso) if typeof cb is 'function'

  create: (cb) ->
    $.post '/api/test', (res) ->
      return console.error(res.error, @) if res.error
      Store.push('tests', res.id, res.key)
      cb(res.id) if typeof cb is 'function'
