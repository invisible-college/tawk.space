plugin_handle = null
streams = {}

###############################################################################
# Client Bus (all state prefixed with tawk/)
###############################################################################

server       = 'state://tawk.space'
janus_server = 'https://tawk.space:8089/janus'

window.statebus_ready or= []
window.statebus_ready.push ->
  sb['tawk/janus_initialized'] = false
  sb['tawk/id'] = random_string(16)
  sb['tawk/space'] = null # Will be filled in dom.TAWK

  unsavable = (obj) ->
    throw new Error("Cannot save #{obj.key}")

  bus('tawk/connections').to_fetch = (key) ->
    _: sb[server + '/connections'].all or []

  bus('tawk/connections').to_save = unsavable

  bus('tawk/connection/*').to_fetch = (key) ->
    target_id = key.split('/')[2]
    conn = sb['tawk/connections'].find (el) -> el.id == target_id

    _: conn or {id: target_id}

  bus('tawk/connection/*').to_save = unsavable

  bus('tawk/_groups').to_fetch = (key) ->
    groups = {}
    for conn in sb['tawk/connections']
      if conn.active and conn.space == sb['tawk/space']
        if conn.group not of groups
          groups[conn.group] = []
        groups[conn.group].push(conn)

    for gid, members of groups
      members.sort (a, b) ->
        return a.timeEntered - b.timeEntered

    _: groups

  bus('tawk/group/*').to_fetch = (key) ->
    gid = key.split('/')[2]

    _:
      members: (sb['tawk/_groups'][gid] or [])

  bus('tawk/gids').to_fetch = (key) ->
    groups = sb['tawk/_groups']
    gids = (gid for gid, members of groups)
    gids.sort (gidA, gidB) ->
      # Uses the fact that members lists are already sorted
      return groups[gidA][0].timeEntered - groups[gidB][0].timeEntered

    _: gids

  bus('tawk/active_connections').to_fetch = (key) ->
    count = 0
    for conn in sb['tawk/connections']
      if conn.active and conn.space == sb['tawk/space']
        count += 1

    _: count

  bus('tawk/dimensions').to_fetch = (key) ->
    connections = sb[server + '/connections']
    active_connections = sb['tawk/active_connections']

    available_width = sb['tawk/width'] - 100 # Margin between groups and edge
    available_height = sb['tawk/height'] - 100 # Some room for scratch space and margin with topbar

    # Calculate dimensions based on if everybody is in one group
    # Hacky way to render groups as big as possible: assume all in one group
    # TODO(karth295): how well does this work with multiple groups,
    # particularly because of the padding necessary between groups?
    size_if_all_in_one_group = group_size(active_connections or 1)
    estimated_width = available_width / size_if_all_in_one_group.width
    estimated_height = available_height / size_if_all_in_one_group.height

    # 35 x 48 is the minimum
    person_height = Math.max(estimated_height, 36)
    person_width = Math.max(estimated_width, 48)

    if person_height > person_width * 3 / 4
      person_height = person_width * 3 / 4
    else if person_width > person_height * 4 / 3
      person_width = person_height * 4 / 3

    _:
      person_height: Math.round(person_height)
      person_width: Math.round(person_width)

###############################################################################
# React render functions
###############################################################################

###
TAWK is the UI for groups that powers sb['tawk/space'].
It supports multiple groups, mute audio/video buttons,
and volume visualization, and a shared text area.

Params:
space (string, default: ''): Identifier for the room.
    Correlates to <space-id> in https://tawk.space/<space-id>

name (string, default: Randomly generated username): User's name
    Appears when hovering over a person.

height (int, required): Height in pixels of widget

width (int, required): Width in pixels of widget

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
  sb['tawk/space'] = if @props.space? then @props.space else ''
  if not sb['tawk/janus_initialized']
    initialize_janus
      audio: true
      video: true
    sb['tawk/janus_initialized'] = true

  if not Janus.isWebrtcSupported() or Janus.webRTCAdapter.browserDetails.browser not in ['chrome', 'firefox']
    return DIV {}, 'Tawk is only supported in Google Chrome or Mozilla Firefox'

  if @props.height && @props.height != sb['tawk/height']
    sb['tawk/height'] = @props.height
  if @props.width && @props.width != sb['tawk/width']
    sb['tawk/width'] = @props.width
  sb['tawk/scratch_disabled'] = !!@props.scratch_disabled

  # Have to make sure we get all connections to choose
  # whether to join the first group
  connections = sb[server + '/connections']
  me = sb[server + '/connection']
  if @loading()
    return DIV {}, 'Loading...'

  name = @props.name or random_name?() or 'Anonymous ' + random_numbers(4)
  video = if @props.video? then @props.video else true
  audio = if @props.audio? then @props.audio else true

  me.name = name  # Is allowed to change
  if not me.id
    # These do not change (yet) if dom.TAWK is rerendered
    # with different arguments
    me.id = sb['tawk/id']
    me.group = sb['tawk/gids'][0] or random_string(16)
    me.timeEntered = Date.now()
    me.active = true
    me.space = sb['tawk/space']
    me.video = video
    me.audio = audio

  DIV
    id: 'tawk'
    style:
      height: sb['tawk/height']
      width: sb['tawk/width']
      clear: 'both'
      textAlign: 'center'
    for gid in sb['tawk/gids']
      GROUP
        gid: gid
    if sb['tawk/drag'].dragging
      GROUP
        gid: sb['tawk/drag'].ghostGroup

dom.GROUP = ->
  gid = @props.gid
  members = sb['tawk/group/' + gid].members or []

  me = sb[server + '/connection']
  me_in_group = me.id in (m.id for m in members)
  divSize = group_size(members.length or 1) # ghost group is size 1

  DIV
    id: gid

    style:
      display: 'inline-block'
      verticalAlign: 'top'
      margin: '20px'
      borderRadius: '15px 15px 15px 15px'
      overflow: if !sb['tawk/drag'].dragging then 'hidden'
      minWidth: divSize.width * sb['tawk/dimensions'].person_width
      maxWidth: divSize.width * sb['tawk/dimensions'].person_width

      # Height varies depending on size of textarea
      # Div around people sets height of that portion

    className: if sb['tawk/drag'].over == gid then 'dark-gray' else 'light-gray'
    onMouseEnter: (e) ->
      sb[server + '/connection'].mouseover = gid

    onMouseLeave: (e) ->
      sb[server + '/connection'].mouseover = null

    if me_in_group && sb['tawk/dimensions'].person_width < 100 # render the AV controls above the group if people are really small
      AV_CONTROL_BAR above: true

    DIV
      style:
        height: divSize.height * sb['tawk/dimensions'].person_height + 'px'
        position: 'relative'
      for user, index in members
        if user != null
          PERSON
            person: user
            position: abs_position_in_group(index, divSize, sb['tawk/dimensions'])

    if members.length && !sb['tawk/scratch_disabled']
      SYNCAREA
        key_: server + '/group/' + gid
        placeholder: 'This is your group scratch space'
        style:
          width: '100%'
          backgroundColor: 'inherit'
          outline: 'none'
          padding: '0.5em'
          borderRadius: '0 0 15px 15px'

dom.GROUP.refresh = ->
  gid = @props.gid

  $(@getDOMNode()).droppable
    tolerance: 'pointer'
    accept: '.person'
    greedy: true
    over: ->
      sb['tawk/drag'].over = gid
    out: ->
      if sb['tawk/drag'].over == gid
        # If not, another over event has fired on another group
        # and we do not want to clear the group
        sb['tawk/drag'].over = null

dom.PERSON = ->
  person = @props.person
  top = @props.position.top
  left = @props.position.left
  me = sb[server + '/connection']
  stream = sb['tawk/stream/' + person.id]
  height = sb['tawk/dimensions'].person_height
  width = sb['tawk/dimensions'].person_width

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
      if person.id == me.id && width > 100
        AV_CONTROL_BAR()
      else
        AV_VIEW_BAR
          person: person
      if person.video
        transform = 'scaleX(-1)'
        if sb['tawk/connection/' + person.id].flip_y
          transform += ' scaleY(-1)'
        DIV
          style:
            transform: transform
            width: '100%'
            height: height + 'px'
          onDoubleClick: if person.id == me.id then =>
            me.flip_y = not me.flip_y
          VIDEO
            autoPlay: 'true'
            style:
              position: 'relative'
              height: '100%'
              width: '100%'
              zIndex: -1
              opacity: .9999 # http://stackoverflow.com/questions/5736503
      else
        DIV
          style:
            backgroundColor: 'black'
            height: '100%'
            width: '100%'
            textAlign: 'center'
            fontSize: (height / 180) + 'em'
            textColor: 'white'

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
            height: height * stream.volume / 180
            width: '20px'
            borderLeft: '5px solid #7FFF00'
          AUDIO
            autoPlay: 'true'

dom.PERSON.refresh = ->
  person = @props.person
  borders = @props.borders
  stream = sb['tawk/stream/' + person.id]
  me = sb[server + '/connection']

  volume = 0
  if person.id != me.id
    if should_hear_fully(person, me)
      volume = 1.0
    else
      volume = 0.04
  vids = @getDOMNode().getElementsByTagName('video')
  if vids.length
    vids[0].volume = 0
    if vids[0].srcObject != streams[person.id]
      vids[0].srcObject = streams[person.id]
  auds = @getDOMNode().getElementsByTagName('audio')
  if auds.length
    auds[0].volume = volume
    if auds[0].srcObject != streams[person.id]
      auds[0].srcObject = streams[person.id]

  if me.id == person.id
    $(@getDOMNode().querySelector('.person')).draggable
      disabled: false
      refreshPositions: true
      zIndex: 1000
      start: (e, ui) ->
        sb['tawk/drag'].over = null # set while you mouseover groups
        sb['tawk/drag'].dragging = true
        sb['tawk/drag'].ghostGroup = random_string 16
      stop: (e, ui) ->
        if not sb['tawk/drag'].over or me.group != sb['tawk/drag'].over
          me.group = sb['tawk/drag'].over or sb['tawk/drag'].ghostGroup
          me.timeEntered = Date.now()

        sb['tawk/drag'].over = null
        sb['tawk/drag'].dragging = false
        sb['tawk/drag'].ghostGroup = null

        ui.helper.css
          top: 0
          left: 0
  else
    $(@getDOMNode().querySelector('.person')).draggable
      disabled: true



dom.AV_CONTROL_BAR = ->
  me = sb[server + '/connection']
  DIV
    style:
      position: if @props.above then 'relative' else 'absolute'
      bottom: if !@props.above then 0
      right: if !@props.above then 0
      zIndex: 100
      textAlign: if @props.above then 'right' else 'center'


    AV_BUTTON
      danger: !me.video
      onClick: (e) ->
        if me.video
          plugin_handle?.muteVideo()
          me.video = false
        else
          plugin_handle?.unmuteVideo()
          me.video = true
        return

      VIDEO_ICON
        on: !!me.video
        width: 16

    AV_BUTTON
      danger: !me.audio
      onClick: (e) ->
        if me.audio
          plugin_handle?.muteAudio()
          me.audio = false
        else
          plugin_handle?.unmuteAudio()
          me.audio = true
        return

      MIC_ICON
        on: !!me.audio
        width: 16

dom.AV_VIEW_BAR = ->
  person = @props.person
  DIV
    style:
      position: 'absolute'
      bottom: 0
      right: 0
      zIndex: 100
      textAlign: 'right'
    if not person.audio
      AV_BUTTON
        disabled: 'disabled'
        danger: true
        dummy: sb['tawk/dimensions'].person_width # needed with react diffing algo, otherwise child component won't get rerendered
        MIC_ICON
          on: false
          width: if sb['tawk/dimensions'].person_width > 100 then 16 else 4


danger_red = '#d43f3a'
dom.AV_BUTTON = ->
  danger = @props.danger
  @transferPropsTo BUTTON
    style:
      border: "1px solid"
      borderColor: if danger then danger_red else '#aaa'

      backgroundImage: if danger then 'linear-gradient(to bottom,#d9534f 0,#c12e2a 100%)' else 'linear-gradient(to bottom,#fff 0,#e0e0e0 100%)'
      textShadow: '0 1px 0 #fff'
      backgroundColor: if danger then danger_red else 'white'
      marginBottom: 0
      padding: '4px 8px'
      borderRadius: 4
    @props.children


VIDEO_ICON = (props) ->
  SVG
    viewBox: "0 0 54 54"
    width: props.width or 20
    height: props.width or 20
    fill: if !props.on then 'white'

    RECT x: 4, y: 11, width: 36, height: 32, rx: 4, ry: 4
    POLYGON points: "32,27 50,13 50,41", strokeLinejoin: 'round'

    if !props.on
      [LINE(x1: 54, y1: 7, x2: 0, y2: 47, stroke: 'white', strokeWidth: 3)
       LINE(x1: 57, y1: 7, x2: 0, y2: 50, stroke: danger_red, strokeWidth: 3)]



MIC_ICON = (props) ->
  SVG
    viewBox: "-3 0 21 24"
    width: props.width or 20
    height: props.width or 20
    fill: if !props.on then 'white'

    PATH
      d: "M12,10V4c0-2.209-1.791-4-4-4S4,1.791,4,4v6c0,2.209,1.791,4,4,4S12,12.209,12,10z"
    PATH
      d: "M0,7v3c0,4.072,3.06,7.435,7,7.931V22h2v-4.069c3.939-0.495,7-3.858,7-7.931V7h-2v3c0,3.309-2.691,6-6,6s-6-2.691-6-6V7H0z"

    if !props.on
      [LINE(x1: 18, y1: 1, x2: 0, y2: 17.5, stroke: 'white', strokeWidth: 3)
       LINE(x1: 18, y1: 4, x2: 0, y2: 20.5, stroke: danger_red, strokeWidth: 3)]


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
  streams[person_id] = stream
  sb['tawk/stream/' + person_id] =
    volume: 0

  # Save volume we receive for each stream to render as a green bar
  speech = hark(stream, {interval: 200, play: false})
  speech.on 'volume_change', (decibals, threshold) ->
    if decibals < threshold
      # Probably not human speech
      decibals = 0
    # Transform to 0-100% scale
    sb['tawk/stream/' + person_id].volume = -2 * decibals

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
        console.error 'no_camera', 'No camera allowed', 'Trying audio-only mode', error
        publish_local_stream
          audio: false
          video: video
      else
        console.error 'no_camera', 'No camera or microphone allowed', 'You are a listener', error

###
Connect to tawk's video server (Janus). Automatically subscribe
to all remote streams in the same space,
and by default automatically publish local stream (though this is configurable).

State imported:
sb['tawk/space'] (string, required) -> The room to subscribe to. Corresponds to <space-id>
    in https://tawk.space/<space-id>. Note that you probably
    don't want to have overlap between spaces used in dom.TAWK
    and directly in initialize_janus. This function subscribes
    to all streams in the space, but dom.TAWK only renders streams
    that are in a groups. The end result is that if you call the lower
    level function you get all the streams, but using dom.TAWK you only
    get a subset of them.
sb['tawk/id'] (string, required): An identifier for the connection that must be unique
    in the given space. It is used to export stream information
    for every user.

State exported:
sb['tawk/stream/' + id] -> {
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
    dependencies: Janus.useDefaultDependencies({fetch:window.og_fetch||window.fetch})
    callback: ->
      if not Janus.isWebrtcSupported() or Janus.webRTCAdapter.browserDetails.browser not in ['chrome', 'firefox']
        alert "Tawk is only supported in Google Chrome or Mozilla Firefox"
        return

      janus = new Janus(
        server: janus_server
        error: console.error
        success: ->
          # Connect to the videoroom plugin
          janus.attach
            plugin: "janus.plugin.videoroom"
            error: console.error
            onlocalstream: (stream) -> recieved_stream(stream, sb['tawk/id'])
            success: (ph) ->
              # Join plugin as a publisher (able to both send and receive streams)
              plugin_handle = ph
              plugin_handle.send
                message:
                  request: "join"
                  room: 1234
                  ptype: "publisher"
                  display: JSON.stringify
                    id: sb['tawk/id']
                    space: sb['tawk/space']
            onmessage: (msg, jsep) ->
              # Janus is informing us of publishers we do not know about
              publishers = msg["publishers"] or []
              for feed in publishers
                {id, space} = JSON.parse feed.display
                if space == sb['tawk/space']
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
