# Tracking mouse positions
# It is sometimes nice to know the mouse position. Let's just make it
# globally available.
window.mouseX = window.mouseY = null
onMouseUpdate = (e) ->
  window.mouseX = e.pageX
  window.mouseY = e.pageY
onTouchUpdate = (e) ->
  window.mouseX = e.touches[0].pageX
  window.mouseY = e.touches[0].pageY
 
document.addEventListener('mousemove', onMouseUpdate, false)
document.addEventListener('mouseenter', onMouseUpdate, false)
 
document.addEventListener('touchstart', onTouchUpdate, false)
document.addEventListener('touchmove', onTouchUpdate, false)
 
 
 
########
# Statebus helpers
 
window.new_key = (type) ->
  '/' + type + '/' + Math.random().toString(36).substring(7)
 
shared_local_key = (key_or_object) ->
  key = key_or_object.key || key_or_object
  if key[0] == '/'
    key = key.substring(1, key.length)
    "#{key}/shared"
  else
    key
 
 
##############
# Manipulating objects
window.extend = (obj) ->
  obj ||= {}
  for arg, idx in arguments 
    if idx > 0
      for own name,s of arg
        if !obj[name]? || obj[name] != s
          obj[name] = s
  obj
 
window.defaults = (obj) ->
  obj ||= {}
  for arg, idx in arguments by -1
    if idx > 0
      for own name,s of arg
        if !obj[name]?
          obj[name] = s
  obj
 
 
 
# ensures that min <= val <= max
within = (val, min, max) ->
  Math.min(Math.max(val, min), max)
 
crossbrowserfy = (styles, property) ->
  prefixes = ['Webkit', 'ms', 'Moz']
  for pre in prefixes
    styles["#{pre}#{property.charAt(0).toUpperCase()}#{property.substr(1)}"]
  styles
 
 
window.get_script_attr = (script, attr) ->
  sc = document.querySelector("script[src*='#{script}'][src$='.coffee'], script[src*='#{script}'][src$='.js']")
  sc.getAttribute(attr)
   
######
# Registering window events.
# Sometimes you want to have events attached to the window that respond back 
# to a particular identifier, and get cleaned up properly. And whose priority
# you can control.
 
window.attached_events = {}
 
register_window_event = (id, event_type, handler, priority) ->
  id = id.key or id
  priority = priority or 0
 
  attached_events[event_type] ||= []
 
  # remove any previous duplicates
  for e,idx in attached_events[event_type]
    if e.id == id
      unregister_window_event(id, event_type)
 
  if attached_events[event_type].length == 0
    window.addEventListener event_type, handle_window_event
 
  attached_events[event_type].push { id, handler, priority }
 
  dups = []
  for e,idx in attached_events[event_type]
    if e.id == id 
      dups.push e
  if dups.length > 1
    console.warn "DUPLICATE EVENTS FOR #{id}", event_type
    for e in dups
      console.warn e.handler
 
unregister_window_event = (id, event_type) ->
  id = id.key or id
 
  for ev_type, events of attached_events
    continue if event_type && event_type != ev_type
 
    new_events = events.slice()
 
    for ev,idx in events by -1
      if ev.id == id 
        new_events.splice idx, 1
 
    attached_events[ev_type] = new_events
    if new_events.length == 0
      window.removeEventListener ev_type, handle_window_event
 
handle_window_event = (ev) ->
  # sort handlers by priority
  attached_events[ev.type].sort (a,b) -> b.priority - a.priority
 
  # so that we know if an event handler stopped propagation...
  ev._stopPropagation = ev.stopPropagation
  ev.stopPropagation = ->
    ev.propagation_stopped = true
    ev._stopPropagation()
 
  # run handlers in order of priority
  for e in attached_events[ev.type]
 
    #console.log "\t EXECUTING #{ev.type} #{e.id}", e.handler
    e.handler(ev)
 
    # don't run lower priority events when the event is no 
    # longer supposed to bubble
    if ev.propagation_stopped #|| ev.defaultPrevented
      break
 
 
 
# Computes the width/height of some text given some styles
size_cache = {}
window.sizeWhenRendered = (str, style) ->
  main = document.getElementById('main-content') or document.querySelector('[data-component="body"]')
 
  return {width: 0, height: 0} if !main
 
  style ||= {}
  # This DOM manipulation is relatively expensive, so cache results
  style.str = str
  key = JSON.stringify style
  delete style.str
 
  if key not of size_cache
    style.display ||= 'inline-block'
 
    test = document.createElement("span")
    test.innerHTML = "<span>#{str}</span>"
    for k,v of style
      test.style[k] = v
 
    main.appendChild test 
    h = test.offsetHeight
    w = test.offsetWidth
    main.removeChild test
 
    size_cache[key] =
      width: w
      height: h
 
  size_cache[key]
 
window.getCoords = (el) ->
  rect = el.getBoundingClientRect()
  docEl = document.documentElement
 
  offset =
    top: rect.top + window.pageYOffset - docEl.clientTop
    left: rect.left + window.pageXOffset - docEl.clientLeft
  extend offset,
    cx: offset.left + rect.width / 2
    cy: offset.top + rect.height / 2
    width: rect.width 
    height: rect.height
 
 
 
# PULSE
# Any component that renders a PULSE will get rerendered on an interval.
# props: 
#   public_key: the key to store the heartbeat at
#   interval: length between pulses, in ms (default=1000)
dom.HEARTBEAT = ->  
  beat = fetch(@props.public_key or 'pulse')
  if !beat.beat?
    setInterval ->   
      beat.beat = (beat.beat or 0) + 1
      save(beat)
    , (@props.interval or 1000)
 
  SPAN null
 
 
dom.AUTOSIZEBOX = ->
  TEXTAREA
    ref: 'textbox'
    rows: 1
    placeholder: @props.placeholder
    onKeyDown: (e) =>@props.onKeyDown?(e)
    onChange: (e) => @props.onChange?(e)
    className: @props.className
    style: @props.style
    value: @props.value
    resize: false  # infinite loop can be triggered if you resize manually,
                   # and then trigger auto resize by typing

resizebox = (target) ->
  while(target.rows > 1 && target.scrollHeight < target.offsetHeight)
    target.rows--
  while(target.scrollHeight > target.offsetHeight)
    target.rows++
    if target.rows > 10000
      console.error 'Infinite loop detected in AUTOSIZEBOX. Exiting.'
      return

dom.AUTOSIZEBOX.up      = -> resizebox(@refs.textbox.getDOMNode())
dom.AUTOSIZEBOX.refresh = -> resizebox(@refs.textbox.getDOMNode())


# Auto growing text area. 
# Transfers props to a TEXTAREA.
dom.GROWING_TEXTAREA = ->
  @props.style ||= {}
  @props.style.minHeight ||= 60
  @props.style.height = \
      @local.height || @props.initial_height || @props.style.minHeight
  @props.style.fontFamily ||= 'inherit'
  @props.style.lineHeight ||= '22px'
  @props.style.resize ||= 'none'
  @props.style.outline ||= 'none'
 
  # save the supplied onChange function if the client supplies one
  _onChange = @props.onChange   
  _onClick = @props.onClick
 
  @props.onClick = (ev) ->
    _onClick?(ev) 
    ev.preventDefault(); ev.stopPropagation()
 
  @props.onChange = (ev) =>
    _onChange?(ev) 
    @adjustHeight()
 
  @adjustHeight = =>
    textarea = @getDOMNode()
 
    if !textarea.value || textarea.value == ''
      h = @props.initial_height || @props.style.minHeight
 
      if h != @local.height
        @local.height = h
        save @local
    else
      min_height = @props.style.minHeight
      max_height = @props.style.maxHeight
 
      # Get the real scrollheight of the textarea
      h = textarea.style.height
      textarea.style.height = '' if @last_value?.length > textarea.value.length
      scroll_height = textarea.scrollHeight
      textarea.style.height = h  if @last_value?.length > textarea.value.length
 
      if scroll_height != textarea.clientHeight
        h = scroll_height + 5
        if max_height
          h = Math.min(scroll_height, max_height)
        h = Math.max(min_height, h)
 
        if h != @local.height
          @local.height = h
          save @local
 
    @last_value = textarea.value
 
  TEXTAREA @props
 
dom.GROWING_TEXTAREA.refresh = ->
  @adjustHeight()
