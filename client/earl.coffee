#########
# Earl
# 
# Hire Earl to handle the browser history & location bar. 
#
# When your web application is loaded, Earl will update your application's 
# bus.fetch('location') state with the url, params, and anchor. Your application 
# can simply react to location state changes as it would any other state change. 
#
# If your application changes the location state, Earl will dutifully update 
# the browser history/location to reflect this change. 
#
# Earl also likes to brag about the souped-up, history-aware dom.A link he 
# offers. It is a drop in replacement for dom.A that will cause internal links
# on your site to update state and browser location without loading a new page.
# Make sure to tell him you want it by setting a history-aware-link attribute
# on the script tag you use to request Earl to attend to your page:
#
# <script src="/path/to/earl.js" history-aware-links></script>
#
# DISCLAIMER: Earl assumes his clients are html5 pushstate history compatible. 
# If you want to serve older non-pushstate compatible browsers try installing the 
# https://github.com/devote/HTML5-History-API polyfill first. 
#
#
# Aside from the public API, you can communicate with Earl through this state:
#    bus.fetch('location')
#         url: the current browser location
#         query_params: browser search values (e.g. blah?foo=fab&bar=nice)
#         hash: the anchor tag (if any) in the link. e.g. blah.html#hash
#         title: the window title
 
 
###################################
# Earl's API (Admissible Professional Inquiries): 
# 
#   Earl.load_page
#     Convenience method for changing the page's url
 
 
 
onload = ->
 
  Earl.root = '/'
  if window.location.pathname.match('.html')
    Earl.root += location.pathname.match(/\/([\w-_]+\.html)/)[1] + '/'
 
  # Earl, don't forget to update us if the browser back or forward button pressed
  window.addEventListener 'popstate', (ev) ->
    Earl.load_page url_from_browser_location()
 
  # By all means Earl, please do initialize location state
  Earl.load_page url_from_browser_location()
 
  # Earl, don't fall asleep on the job!
  react_to_location()
 
if window.addEventListener
  window.addEventListener 'load', onload, false 
else if window.attachEvent
  window.attachEvent 'onload', onload
 
 
 
window.Earl =
 
  # Updating the browser window location. 
  load_page: (url, query_params) ->
    loc = bus.fetch('location')
    loc.host = window.location.host
    loc.query_params = query_params or {}
 
    # if the url has query parameters, parse and merge them into params
    if url.indexOf('?') > -1
      [url, query_params] = url.split('?')
 
      for query_param in query_params.split('&')
        query_param = query_param.split('=')
        if query_param.length == 2
          loc.query_params[query_param[0]] = query_param[1]
 
    # ...and parse anchors
    hash = ''
    if url.indexOf('#') > -1
      [url, hash] = url.split('#')
      url = '/' if url == ''
 
      # When loading a page with a hash, we need to scroll the page
      # to proper element represented by that id. This is hard to 
      # represent in Statebus, as it is more of an event than state.
      # We'll set seek_to_hash here, then it will get set to null 
      # after it is processed. 
      seek_to_hash = true
 
    loc.url = url or '/'
    loc.hash = hash
    bus.save loc
 
 
 
##################################
# Internal
 
 
# Enables history aware link. Wraps basic dom.A.
sc = document.querySelector('script[src*="earl"][src$=".coffee"], script[src*="earl"][src$=".js"]')
hist_aware = sc.getAttribute('history-aware-links')?.toLowerCase() != 'false'
 
 
if hist_aware
 
  window.dom = window.dom || {}
 
  dom.A = ->
    props = @props
    if @props.href
 
      # Earl will call a click handler that the programmer passes in
      onClick = @props.onClick or (-> null)
 
      handle_click = (event) =>
        href = @props.href
 
        internal_link = !href.match('//') || !!href.match(location.origin)
        is_mailto = !!href.toLowerCase().match('mailto')
        opened_in_new_tab = event.altKey  || \
                            event.ctrlKey || \
                            event.metaKey || \
                            event.shiftKey
         
        # In his wisdom, Earl sometimes just lets the default behavior occur
        if !internal_link || opened_in_new_tab || is_mailto \
           || @props.target == '_blank'
          onClick event
 
        # ... but other times Earl is history aware
        else
          event.preventDefault()
          event.stopPropagation()
          Earl.load_page href
          onClick event
 
          # Upon navigation to a new page, it is conventional to be scrolled
          # to the top of that page. Earl obliges. Pass noScroll:true to 
          # the history aware dom.A if you don't want Earl to do this. 
          window.scrollTo(0, 0) if !@props.noScroll           
                           
          return false
 
      if is_mobile
        @props.onTouchEnd = (e) ->
          # Earl won't make you follow the link if you're in the middle of swipping
          if !Earl._user_swipping
            handle_click e
 
        if is_android_browser # Earl's least favorite browser to support...
          @props.onClick = (e) -> e.preventDefault(); e.stopPropagation()
 
      else
        @props.onClick = handle_click
 
    React.DOM.a props, props.children
 
 
# Earl's Reactive nerves keep him vigilant in making sure that changes in location
# state are reflected in the browser history. Earl also updates the window title 
# for you, free of charge, if you set bus.fetch('location').title.
 
react_to_location = ->
  monitor = bus.reactive ->
 
    loc = bus.fetch 'location'
 
    # Update the window title if it has changed
    title = location.title or document.title
    if title && title != location.title
      document.title = title
 
    # Respond to a location change
    new_location = url_from_statebus()
    if @last_location != new_location 
 
      # update browser history if it hasn't already been updated
      if url_from_browser_location() != new_location
        h = (Earl.root + new_location)
        history.pushState loc.query_params, title, h.replace(/(\/){2,}/, '/').replace(/(\/)$/, '')
 
      @last_location = new_location
 
    # If someone clicked a link with an anchor, Earl strives to scroll
    # the page to that element. Unfortunately, Earl isn't powerful 
    # enough to deal with the mightly Webkit browser's imposition of 
    # a remembered scroll position for a return visitor upon initial 
    # page load!
    if seek_to_hash 
      seek_to_hash = false
      el = document.querySelector("##{loc.hash}")
      if el
        $(window).scrollTop getCoords(el).top - 50
  monitor()
 
seek_to_hash = false 
 
url_from_browser_location = ->
  # location.search returns the query parameters
 
  # fix url encoding
  search = location.search?.replace(/\%2[fF]/g, '/')
  loc = location.pathname?.replace(/\%20/g, ' ')
 
  if Earl.root
    loc = (loc + '/').split(Earl.root)[1]
 
  "#{loc}#{search}#{location.hash}"
 
url_from_statebus = ->
  loc = bus.fetch 'location'
 
  relative_url = loc.url or '/'
 
  if loc.query_params && Object.keys(loc.query_params).length > 0
    query_params = ("#{k}=#{v}" for own k,v of loc.query_params)
    relative_url += "?#{query_params.join('&')}"
  if loc.hash?.length > 0
    relative_url += "##{loc.hash}"
 
  relative_url
 
 
# For handling device-specific annoyances
document.ontouchmove = (e) -> Earl._user_swipping = true
document.ontouchend  = (e) -> Earl._user_swipping = false
rxaosp = window.navigator.userAgent.match /Android.*AppleWebKit\/([\d.]+)/
is_android_browser = !!(rxaosp && rxaosp[1]<537)
ua = navigator.userAgent
is_mobile = is_android_browser || \
  ua.match(/(Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone)/i)
