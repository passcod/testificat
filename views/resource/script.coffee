# Little hack to recall ourselves when
# $(document).ready() executes. One less
# level of indentation is always good!
rootob = this
rootfn = arguments.callee
firstp = arguments[0] != 'jq'
return ($ -> rootfn.call(rootob, 'jq')) if firstp


# The Store is basically a singleton,
# but there's no need to enforce that
# as we're within a closure.
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


# Just wrapping the API in easy-to-use functions…
@Test =
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
    $.ajax
      method: 'POST'
      url: '/api/test'
      dataType: 'json'
      complete: (res) ->
        jso = res.responseJSON
        return console.error(res) unless jso
        return console.error(jso.error, @) if jso.error
        Store.push('tests', jso.id, jso.key)
        cb(jso.id) if typeof cb is 'function'

  addCase: (id, content, cb) ->
    $.ajax
      method: 'PUT'
      url: '/api/test'
      data: JSON.stringify {
        id: id
        content: content
        key: Store.get('tests')[id]
      }
      dataType: 'json'
      complete: (res) ->
        jso = res.responseJSON
        return console.error(res) unless jso
        return console.error(jso.error, @) if jso.error
        cb(jso) if typeof cb is 'function'
  
  vote: (id, cas, cb) ->
    $.ajax
      method: 'POST'
      url: '/api/vote'
      data: JSON.stringify {
        id: id
        case: cas
      }
      dataType: 'json'
      complete: (res) ->
        jso = res.responseJSON
        return console.error(res) unless jso
        return console.error(jso.error, @) if jso.error
        cb(jso) if typeof cb is 'function'

  unvote: (id, cb) ->
    $.ajax
      method: 'DELETE'
      url: '/api/vote'
      data: JSON.stringify {
        id: id
      }
      dataType: 'json'
      complete: (res) ->
        jso = res.responseJSON
        return console.error(res) unless jso
        return console.error(jso.error, @) if jso.error
        cb(jso) if typeof cb is 'function'
 

# This is the homepage's and edit form's
# "Add test case" button.
$('button.add').click ->
  $cases = $('.case')
  $newca = $cases.first().clone()
  $textc = $('textarea', $newca)
  $textc.val('')
  $cases.last().after($newca)
  $textc.focus()

# This is the homepage's create button.
$('button.create').click ->
  $cases = $('.case')
  cases = []
  $cases.each -> cases.push $('textarea', @).val()
  
  Test.create (id) ->
    async.each cases, (item, cb) ->
      Test.addCase id, item, -> cb()
    , (err) ->
      return console.error(err) if err
      location.replace "/test/#{id}"

# This is the testpage's (un)vote buttons
$('.case button.vote').click ->
  $this = $(@)
  $case = $(@).parents('.case')
  $test = $('#test')
  if $case.attr('data-vote') != undefined
    Test.unvote($test.data('id'))
    $case.removeAttr('data-vote')
    $this.text('Vote')
  else
    Test.vote($test.data('id'), $case.data('id'))
    $other = $('.case[data-vote]')
    $other.removeAttr('data-vote')
    $('button.vote', $other).text('Vote')
    $case.attr('data-vote', true)
    $this.text('Unvote')
