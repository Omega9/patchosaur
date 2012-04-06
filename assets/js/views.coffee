
patchagogy = @patchagogy = @patchagogy or {}

patchagogy.ObjectView = Backbone.View.extend {
  initialize: () ->
    # get elements inside a span or div?
    @p = patchagogy.paper
    @patchView = @options.patchView
    @id = _.uniqueId 'objectView_'
    @model.set 'view', @
    # bind events
    @model.bind 'change:connections', => @drawConnections true
    @model.bind 'change:x change:y', => do @place
    # triggered by patch view when x or y change on any obj
    @bind 'redrawConnections', => @drawConnections false

    @connections = []
    @raphaelBox = null
    @raphaelText = null
    @inlets  = []
    @outlets = []
    @textOffset = [0, 0]
    # make it
    do @render
    @raphaelSet.forEach (el) =>
      el.node.setAttribute 'class', @id

  clear: () ->
    # FIXME: what are we leaving behind?
    # @?
    do @raphaelSet.remove
    # # calling destroy on this model tries to phone home
    @model.clear()
    patchagogy.objects.remove(@model)

  place: () ->
    x = @model.get 'x'
    y = @model.get 'y'
    for elem in _.flatten [@raphaelBox, @raphaelText, @inlets, @outlets]
      elem.attr
        x: x + (elem.offsetX or 0)
        y: y + (elem.offsetY or 0)
    @p.safari()

  drawConnections: (redraw=true) ->
    # try to move current connections
    if not redraw and not _.isEmpty @connections
      for connection in @connections
        @p.connection connection
      return
    # else, clear current and redo
    for connection in @connections
      connection.line.remove()
    @connections = []
    connections = @model.get 'connections'
    # console.log @model.get('text'), connections
    for outlet of connections
      for to in connections[outlet]
        toID = to[0]
        inlet = to[1]
        toElem = patchagogy.objects.get toID
        conn = @p.connection @outlets[outlet], toElem.get('view').inlets[inlet], '#f00'
        @connections.push conn
        @raphaelSet.push conn

  _setOffset: (onEl, fromEl) ->
    onEl.offsetX = onEl.attrs.x - fromEl.attrs.x
    onEl.offsetY = onEl.attrs.y - fromEl.attrs.y

  render: () ->
    @raphaelSet?.remove()
    do @p.setStart
    console.log 'rendering object view', @id, @
    drawConnections = (redraw) => @drawConnections redraw
    p = @p
    x = @model.get 'x'
    y = @model.get 'y'
    text = @model.get 'text'
    textElem = @p.text x, y, text
    @raphaelText = textElem
    box = textElem.getBBox()
    padding = 2
    rect = @p.rect box.x - 2, box.y - 2, box.width + 4, box.height + 4, 2
    @raphaelBox = rect
    @rect = rect
    @_setOffset @raphaelText, @raphaelBox

    rect.attr {
      fill: '#a00'
      stroke: '#e03'
      "fill-opacity": 0
      "stroke-width": 2
      cursor: "move"
    }
    # make inlets and outlets
    # FIXME: this is the same code twice. clean up.
    inlet.remove() for inlet in @inlets
    outlet.remove() for outlet in @outlets
    @inlets = []
    @outlets = []
    numInlets = @model.get 'numInlets'
    numOutlets = @model.get 'numOutlets'
    padding = 5
    width = box.width - (padding * 2)
    spacing = width / (numInlets - 1) # FIXME? work for one?
    for inlet in _.range numInlets
      inletElem = @p.rect(
        box.x + padding - 2 + (inlet * spacing),
        box.y - 6,
        6, 4, 1)
      @_setOffset inletElem, rect
      inletElem.attr fill: '#9b9'
      @inlets.push inletElem
    spacing = width / (numOutlets - 1) # FIXME? work for one?
    for outlet in _.range numOutlets
      outletElem = @p.rect(
        box.x + padding - 2 + (outlet * spacing),
        box.height + box.y + 2,
        6, 4, 1)
      @_setOffset outletElem, rect
      outletElem.attr fill: '#99f'
      @outlets.push outletElem

    # FIXME: set on the view or model?
    # i think on the patch view
    # activeOutlet, on inlet clicks
    # if there's an active outlet, tell model about connection
    _.each @outlets, (outlet, i) =>
      outlet.click (event) =>
        glowee = outlet.glow()
        anim = Raphael.animation {"stroke-width": 12}, 400
        anim = anim.repeat Infinity
        glowee.animate anim
        @patchView.setActiveOutlet
          modelID: @model.id
          index: i
          el: glowee

    _.each @inlets, (inlet, i) =>
      inlet.click (event) =>
        @patchView.setInlet
          modelID: @model.id
          index: i

    # glow on hover
    _.each _.flatten([@outlets, @inlets]), (xlet) ->
      xlet.hover (event) ->
        xlet.glowEl = xlet.glow()
      , (event) ->
        xlet.glowEl.remove()

    # set up dragging behavior
    self = @
    startDrag = ->
      @ox = @attr 'x'
      @oy = @attr 'y'
      rt = self.raphaelText
      rt.ox = rt.attr 'x'
      rt.oy = rt.attr 'y'
      @animate({"fill-opacity": .3}, 200)
    endDrag = (event) ->
      @animate({"fill-opacity": 0}, 700)
    move = (dx, dy) ->
      att = {x: @ox + dx, y: @oy + dy}
      # set on model, triggers events to redraw
      self.model.set att
    move = _.throttle move, 22
    rect.drag move, startDrag, endDrag
    drawConnections()
    @raphaelSet = do @p.setFinish
    @raphaelSet.click (event) =>
      if event.shiftKey
        do @clear
}

patchagogy.PatchView = Backbone.View.extend {
  el: $('#holder')
  initialize: () ->
    @objects = @options.objects
    @svgEl = @$el.children('svg').get 0
    @objectViews = []
    @objects.bind 'add', (object) =>
      console.log 'new view for', object
      # FIXME: can we do without this?
      # @objectViews.push new patchagogy.ObjectView model: object
      new patchagogy.ObjectView
        model: object
        patchView: @
    @objects.bind 'change:x change:y', (changedObject) =>
      affected = @objects.connectedFrom changedObject
      _.each affected, (object) ->
        object.get('view').trigger 'redrawConnections'

    # set up creating new 
    # objects with ctrl click
    @$el.on 'click', (event) =>
      if event.target == @svgEl and event.shiftKey
        x = event.pageX
        y = event.pageY
        @objects.newObject
          x: event.pageX
          y: event.pageY
          text: 'omg i added this'

  setActiveOutlet: (data) ->
    @activeOutlet?.el.remove()
    @activeOutlet = data

  getActiveOutlet: -> @activeOutlet

  setInlet: (data) ->
    outletData = do @getActiveOutlet
    return if not outletData
    from = patchagogy.objects.get outletData.modelID
    to   = patchagogy.objects.get data.modelID
    # FIXME: if connected then disconnect?
    from.connect outletData.index, data.modelID, data.index
    @setActiveOutlet undefined
}
