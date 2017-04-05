plugin_handle = null

###############################################################################
# Client Bus (exported through global variable)
###############################################################################

window.statebus_ready or= []
window.statebus_ready.push(->
  window.tawkbus = window.statebus()
  tawkbus.sockjs_client('/*', 'state://tawk.space')
  window.tawk = tawkbus.sb

  tawk.janus_initialized = false
  tawk.id = random_string(16)
  tawk.space = null # Will be filled in dom.TAWK

  unsavable = (obj) ->
    throw new Error("Cannot save #{obj.key}")

  tawkbus('connections').to_fetch = (key) ->
    connections = tawk['/connections']
    if not connections.all
      connections.all = []

    _: tawk['/connections'].all or []

  tawkbus('connections').to_save = unsavable

  tawkbus('connection/*').to_fetch = (key) ->
    target_id = key.split('/')[1]
    conn = tawk.connections.find (el) -> el.id == target_id

    _: conn or {id: target_id}

  tawkbus('connection/*').to_save = unsavable

  tawkbus('_groups').to_fetch = (key) ->
    groups = {}
    for conn in tawk.connections
      if conn.active and conn.space == tawk.space
        if conn.group not of groups
          groups[conn.group] = []
        groups[conn.group].push(conn)

    for gid, members of groups
      members.sort (a, b) ->
        return a.timeEntered - b.timeEntered

    _: groups

  tawkbus('group/*').to_fetch = (key) ->
    gid = key.split('/')[1]

    _:
      members: (tawk._groups[gid] or [])

  tawkbus('gids').to_fetch = (key) ->
    groups = tawk._groups
    gids = (gid for gid, members of groups)
    gids.sort (gidA, gidB) ->
      # Uses the fact that members lists are already sorted
      return groups[gidA][0].timeEntered - groups[gidB][0].timeEntered

    _: gids

  tawkbus('active_connections').to_fetch = (key) ->
    count = 0
    for conn in tawk.connections
      if conn.active and conn.space == tawk.space
        count += 1

    _: count

  tawkbus('dimensions').to_fetch = (key) ->
    connections = tawk['/connections']
    active_connections = tawk.active_connections

    screen_width = tawk.window.width
    screen_height = tawk.window.height

    # 240 x 180 is the minimum
    person_height = 180
    person_width = 240

    # Hacky way to render groups as big as possible
    # when there are only a few people in the space
    if active_connections <= 1
      person_height = Math.max(screen_height - 60, person_height)
      person_width = Math.max(screen_width / 2 - 60, person_width)
    else if active_connections <= 2
      person_height = Math.max(screen_height - 60, person_height)
      person_width = Math.max(screen_width / 3 - 60, person_width)
    else if active_connections <= 4
      person_height = Math.max(screen_height / 2 - 60, person_height)
      person_width = Math.max(screen_width / 3 - 60, person_width)
    else if active_connections <= 7
      person_height = Math.max(screen_height / 2 - 60, person_height)
      person_width = Math.max(screen_width / 4 - 60, person_width)

    if person_height > person_width * 3 / 4
      person_height = person_width * 3 / 4
    else if person_width > person_height * 4 / 3
      person_width = person_height * 4 / 3

    _:
      person_height: Math.round(person_height)
      person_width: Math.round(person_width)

  tawkbus('window').to_fetch = (key) ->
    _:
      width: window.innerWidth
      height: window.innerHeight - $("#topbar").outerHeight(true)

  window.onresize = () ->
    tawkbus.dirty 'window'
)
###############################################################################
# React render functions
###############################################################################

###
TAWK is the UI for groups that powers tawk.space.
It supports multiple groups, mute audio/video buttons,
and volume visualization, and a shared text area.

Params:
space (string, default: ''): Identifier for the room.
    Correlates to <space-id> in https://tawk.space/<space-id>

name (string, default: Randomly generated username): User's name
    Appears when hovering over a person.

video (boolean, default: true): Whether to default publish video

audio (boolean, default: true): Whether to default publish audio

Note that audio and video only refer to the default state of whether
user is publishing their audio or video. They can use the buttons
to mute/unmute their audio and video. The user will be asked for
camera and microphone permissions regardless of the values of these booleans.

This widget can only be used from an https site, since WebRTC
is only supported on https sites.
###
dom.TAWK = ->
  tawk.space = if @props.space? then @props.space else ''
  if not tawk.janus_initialized
    initialize_janus
      audio: true
      video: true
    tawk.janus_initialized = true

  # Have to make sure we get all connections to choose
  # whether to join the first group
  connections = tawk['/connections']
  me = tawk['/connection']
  if @loading()
    return DIV {}, 'Loading...'
  
  name = @props.name or random_name?() or 'Anonymous ' + random_numbers(4)
  video = if @props.video? then @props.video else true
  audio = if @props.audio? then @props.audio else true

  me.name = name  # Is allowed to change
  if not me.id
    # These do not change (yet) if dom.TAWK is rerendered
    # with different arguments
    me.id = tawk.id
    me.group = tawk.gids[0] or random_string(16)
    me.timeEntered = Date.now()
    me.active = true
    me.space = tawk.space
    me.video = video
    me.audio = audio

  DIV
    id: 'tawk'
    style:
      height: 'auto'
      minHeight: '85%'
      clear: 'both'
    for gid in tawk.gids
      GROUP
        gid: gid
    if tawk.drag.dragging
      GROUP
        gid: tawk.drag.ghostGroup

dom.GROUP = ->
  gid = @props.gid
  members = tawk['group/' + gid].members or []

  group_info = tawk['/group/' + gid]
  group_editing = tawk['editing-' + gid]
  if not group_editing.timer
    group_editing.text = (if group_info.text == undefined then 'This is your group scratch space' else group_info.text)

  divSize = group_size(members.length or 1) # ghost group is size 1

  DIV
    id: gid
    className: (if tawk.drag.over == gid then 'dark-gray' else 'light-gray')
    style:
      float: 'left'
      margin: '20px'
      borderRadius: '15px'
      minWidth: divSize.width * tawk.dimensions.person_width + 'px'
      maxWidth: divSize.width * tawk.dimensions.person_width + 'px'
      # Height varies depending on size of textarea
      # Div around people sets height of that portion

    onMouseEnter: (e) ->
      tawk['/connection'].mouseover = gid

    onMouseLeave: (e) ->
      tawk['/connection'].mouseover = null

    DIV
      style:
        height: divSize.height * tawk.dimensions.person_height + 'px'
        position: 'relative'
      for user, index in members
        if user != null
          PERSON
            person: user
            borders: choose_borders(index, divSize)
            position: abs_position_in_group(index, divSize, tawk.dimensions)
    if members.length
      GROWING_TEXTAREA
        className: 'form-control'
        rows: 2
        style:
          clear: 'both'
          width: '100%'
          backgroundColor: 'inherit'
          borderBottomLeftRadius: '15px'
          borderBottomRightRadius: '15px'
          outline: 'none'
          border: '1px solid #aaa'
        value: group_editing.text
        onChange: (e) ->
          group_editing.text = e.target.value
          if group_editing.timer
            clearTimeout group_editing.timer
          group_editing.timer = setTimeout ->
            group_editing.timer = null
            group_info.text = group_editing.text
          , 500

dom.GROUP.refresh = ->
  gid = @props.gid

  $(@getDOMNode()).droppable
    tolerance: 'pointer'
    accept: '.person'
    greedy: true
    over: ->
      tawk.drag.over = gid
    out: ->
      if tawk.drag.over == gid
        # If not, another over event has fired on another group
        # and we do not want to clear the group
        tawk.drag.over = null

dom.PERSON = ->
  person = @props.person
  borders = @props.borders
  top = @props.position.top
  left = @props.position.left
  me = tawk['/connection']
  stream = tawk['stream/' + person.id]
  height = tawk.dimensions.person_height
  width = tawk.dimensions.person_width

  DIV
    position: 'absolute'
    left: left
    top: top
    DIV
      title: person.name
      id: person.id
      className: 'person'
      style:
        height: height + 'px'
        width: width + 'px'
        cursor: (if person.id == me.id then 'pointer' else '')
        opacity: (if should_hear_fully(person, me) then 1.0 else 0.5)
      if person.id == me.id
        AV_CONTROL_BAR()
      else
        AV_VIEW_BAR
          person: person
      if person.video
        transform = 'scaleX(-1)'
        if tawk['connection/' + person.id].flip_y
          transform += ' scaleY(-1)'
        DIV
          style:
            transform: transform
            width: '100%'
            height: height + 'px'
          onDoubleClick: =>
            me.flip_y = not me.flip_y
          VIDEO
            autoPlay: 'true'
            src: stream.url
            style:
              position: 'relative'
              height: '100%'
              width: '100%'
              zIndex: '-1'
              # These properties are flipped horizontally because the div is flipped horizontally
              borderTopLeftRadius: (if borders.topRight then '10px' else '')
              borderTopRightRadius: (if borders.topLeft then '10px' else '')
      else
        DIV
          style:
            backgroundColor: 'black'
            height: '100%'
            width: '100%'
            textAlign: 'center'
            fontSize: (height / 180) + 'em'
            textColor: 'white'
            borderTopLeftRadius: (if borders.topLeft then '10px' else '')
            borderTopRightRadius: (if borders.topRight then '10px' else '')
          DIV {},
            DIV
              person.name
            BR {},
            DIV
              if person.audio
                '(Audio-Only)'
              else
                '(Muted)'
      if person.audio
        DIV
          style:
            position: 'absolute'
            bottom: 0
            right: 0
            height: stream.volume + 'px'
            width: '20px'
            borderLeft: '5px solid #7FFF00'
          AUDIO
            autoPlay: 'true'
            src: stream.url

dom.PERSON.refresh = ->
  person = @props.person
  borders = @props.borders
  stream = tawk['stream/' + person.id]
  me = tawk['/connection']

  volume = 0
  if person.id != me.id
    if should_hear_fully(person, me)
      volume = 1.0
    else
      volume = 0.04
  vids = @getDOMNode().getElementsByTagName('video')
  if vids.length
    vids[0].volume = 0
  auds = @getDOMNode().getElementsByTagName('audio')
  if auds.length
    auds[0].volume = volume

  if me.id == person.id
    $(@getDOMNode().querySelector('.person')).draggable
      disabled: false
      refreshPositions: true
      zIndex: 1000
      start: (e, ui) ->
        tawk.drag.over = null # set while you mouseover groups
        tawk.drag.dragging = true
        tawk.drag.ghostGroup = random_string 16
      stop: (e, ui) ->
        if not tawk.drag.over or me.group != tawk.drag.over
          me.group = tawk.drag.over or tawk.drag.ghostGroup
          me.timeEntered = Date.now()

        tawk.drag.over = null
        tawk.drag.dragging = false
        tawk.drag.ghostGroup = null

        ui.helper.css
          top: 0
          left: 0
  else
    $(@getDOMNode().querySelector('.person')).draggable
      disabled: true

dom.AV_CONTROL_BAR = ->
  me = tawk['/connection']
  DIV
    style:
      position: 'absolute'
      width: '100%'
      bottom: '0'
      left: '0'
      zIndex: '100'
      textAlign: 'right'
    BUTTON
      className: 'btn btn-' + (if me.video then 'default' else 'danger')
      SPAN
        className: 'fa fa-video-camera' + (if me.video then '' else '-slash')
      onClick: (e) ->
        if me.video
          plugin_handle and plugin_handle.muteVideo()
          me.video = false
        else
          plugin_handle and plugin_handle.unmuteVideo()
          me.video = true
    BUTTON
      className: 'btn btn-' + (if me.audio then 'default' else 'danger')
      SPAN
        className: 'fa fa-microphone' + (if me.audio then '' else '-slash')
      onClick: (e) ->
        if me.audio
          plugin_handle and plugin_handle.muteAudio()
          me.audio = false
        else
          plugin_handle and plugin_handle.unmuteAudio()
          me.audio = true

dom.AV_VIEW_BAR = ->
  person = @props.person
  DIV
    style:
      position: 'absolute'
      width: '100%'
      bottom: '0'
      left: '0'
      zIndex: '100'
      textAlign: 'right'
    if not person.audio
      BUTTON
        className: 'btn btn-danger'
        disabled: 'disabled'
        SPAN
          className: 'fa fa-microphone-slash'

random_string = (length) ->
  Math.round((Math.pow(36, length + 1) - Math.random() * Math.pow(36, length)))
    .toString(36)
    .slice(1)

random_numbers = (length) ->
  Math.round((Math.pow(10, length + 1) - Math.random() * Math.pow(10, length)))
    .toString(10)
    .slice(1)

should_hear_fully = (person, me) ->
  me.group in [person.group, person.mouseover] or
    (me.mouseover in [person.group, person.mouseover] and me.mouseover != null)

group_size = (num_people) ->
  floor = Math.floor(Math.sqrt(num_people))
  ceil = Math.ceil(Math.sqrt(num_people))

  if floor == ceil
    height: floor
    width: floor
  else if num_people > floor * ceil
    height: ceil
    width: ceil
  else
    height: floor
    width: ceil

choose_borders = (index, divSize) ->
  x = index % divSize.width
  y = Math.floor(index / divSize.width)

  topLeft: (x == 0 and y == 0)
  topRight: (x == divSize.width - 1 and y == 0)

abs_position_in_group = (index, divSize, dimensions) ->
  x = index % divSize.width
  y = Math.floor(index / divSize.width)

  top: y * dimensions.person_height
  left: x * dimensions.person_width

###############################################################################
# Send and receive video streams
###############################################################################

# This section is a little complicated because Janus requires multiple
# roundtrips for nearly everything. Suggestions on improvement are welcome.

recieved_stream = (stream, person_id) ->
  # Put stream (url) in state so the audio/video can be rendered
  tawk['stream/' + person_id] =
    url: URL.createObjectURL(stream)
    volume: 0

  # Save volume we receive for each stream to render as a green bar
  speech = hark(stream, {interval: 200, play: false})
  speech.on 'volume_change', (decibals, threshold) ->
    if decibals < threshold
      # Probably not human speech
      decibals = 0
    # Transform to 0-100% scale
    tawk['stream/' + person_id].volume = -2 * decibals

# Tell Janus to publish our video stream to the server
# Note that the hook when we get a local stream is actually
# a separate callback to janus.attach
window.publish_local_stream = ({audio, video}) ->
  plugin_handle.createOffer
    media:
      audioRecv: false
      videoRecv: false
      audioSend: audio
      videoSend: video
    success: (jsep) ->
      plugin_handle.send
        message:
          request: "configure"
          audio: audio
          video: video
        jsep: jsep
    error: (error) ->
      if audio
        audio = false
        console.error 'no_camera', 'No camera allowed', 'Trying audio-only mode', error
        publish_local_stream()
      else
        console.error 'no_camera', 'No camera or microphone allowed', 'You are a listener', error

###
Connect to tawk's video server (Janus). Automatically subscribe
to all remote streams in the same space,
and by default automatically publish local stream (though this is configurable).

State imported:
tawk.space (string, required) -> The room to subscribe to. Corresponds to <space-id>
    in https://tawk.space/<space-id>. Note that you probably
    don't want to have overlap between spaces used in dom.TAWK
    and directly in initialize_janus. This function subscribes
    to all streams in the space, but dom.TAWK only renders streams
    that are in a groups. The end result is that if you call the lower
    level function you get all the streams, but using dom.TAWK you only
    get a subset of them.
tawk.id (string, required): An identifier for the connection that must be unique
    in the given space. It is used to export stream information
    for every user.

State exported:
tawk['streams/' + id] -> {
  url: A blob url for the stream. It can be used in audio or video tags with src: url
  volume: On a scale from 0-100, how loud is the user speaking.
      Volume tries to reflect human speech, and ignore static background noise.
}
There will be one piece of state exported per remote *and* local stream.

Params:
audio (boolean, default=true): Whether to subscribe to and publish audio
video (boolean, default=true): Whether to subscribe to and publish video
on_join (function({audio, video}), default=window.publish_local_stream):
    A callback for when we have connected to Janus and its videoroom plugin.
    The default callback is to immediately publish your local stream and ask
    the user for permission to their camera and/or microphone. You can
    override this callback if you do not wish to immediately publish the local stream.
    The callback takes {audio, video}, which are the same values passed
    into initialize_janus, and represent whether the caller wants to publish
    audio and video.
###
window.initialize_janus = ({audio = true, video = true, on_join = window.publish_local_stream}) ->
  new_remote_feed = (janus, feed) ->
    remote_feed = null
    {id, space} = JSON.parse feed.display
    janus.attach
      plugin: "janus.plugin.videoroom"
      onremotestream: (stream) -> recieved_stream(stream, id)
      error: console.error
      success: (ph) ->
        remote_feed = ph
        remote_feed.send
          message:
            request: "join"
            room: 1234
            ptype: "listener"
            feed: feed.id
      onmessage: (msg, jsep) ->
        if jsep
          remote_feed.createAnswer
            jsep: jsep
            error: console.error
            media:
              audioRecv: audio
              videoRecv: video
              audioSend: false
              videoSend: false
            success: (jsep) ->
              remote_feed.send
                jsep: jsep
                message:
                  request: "start"
                  room: 1234

  Janus.init
    callback: ->
      if not Janus.isWebrtcSupported()
        alert "No WebRTC support in your browser. You must use Chrome, Firefox, or Edge"

      janus = new Janus(
        server: 'https://tawk.space:8089/janus'
        error: console.error
        success: ->
          # Connect to the videoroom plugin
          janus.attach
            plugin: "janus.plugin.videoroom"
            error: console.error
            onlocalstream: (stream) -> recieved_stream(stream, tawk.id)
            success: (ph) ->
              # Join plugin as a publisher (able to both send and receive streams)
              plugin_handle = ph
              plugin_handle.send
                message:
                  request: "join"
                  room: 1234
                  ptype: "publisher"
                  display: JSON.stringify
                    id: tawk.id
                    space: tawk.space
            onmessage: (msg, jsep) ->
              # Janus is informing us of publishers we do not know about
              publishers = msg["publishers"] or []
              for feed in publishers
                {id, space} = JSON.parse feed.display
                if space == tawk.space
                  new_remote_feed janus, feed

              # The plugin_handle.send call to join as a publisher succeeded.
              # We can now send our video to everybody
              if msg["videoroom"] == "joined"
                on_join
                  audio: audio
                  video: video

              if jsep
                plugin_handle.handleRemoteJsep
                  jsep: jsep
      )
