local passion = {}
passion.mousepos = {nil, nil}
passion.state = {
  events = {},
  components = {}
}

--Constructors -----------------------------------------
function passion.box(spassion, x, y, w, h)
  local box = {x, y, w, h}

  function box.split(...) return spassion:split(...) end
  function box.fill(...) return spassion:fill(...) end
  function box.inset(...) return spassion:inset(...) end
  function box.outset(...) return spassion:outset(...) end
  function box.third(...) return spassion:third(...) end
  function box.quarter(...) return spassion:quarter(...) end
  function box.squarify(...) return spassion:squarify(...) end
  function box.segment(...) return spassion:segment(...) end
  function box.transform(...) return spassion:transform(...) end
  function box.inside(box, px, py)
    local x, y, w, h = unpack(box)
    return px >= x and py >= y and px <= x + w and py <= y + h
  end

  return box
end

function passion:root()
  return self:box(
    0, 0,
    love.graphics.getWidth(),
    love.graphics.getHeight()
  )
end

-- Box Manipulation -----------------------------------------
function passion:split(box, direction, percent, inset)
  box = box:inset(inset)
  local x, y, w, h = unpack(box)

  -- Create New Boxes
  if direction == 'vertical' then
    local a = self:box(
      x, y,
      w * percent, h
    )

    local b = self:box(
      x + w*percent, y,
      w * (1 - percent), h
    )

    return a, b
  end

  if direction == 'horizontal' then
    local a = self:box(
      x, y,
      w, h * percent
    )

    local b = self:box(
      x, y + h*percent,
      w, h * (1 - percent)
    )

    return a, b
  end
end

function passion:third(box, direction, inset)
  local a, b = box:split(direction, .333, inset)
  local _, c = box:split(direction, .666, inset)
  b, _ = b:split(direction, .5, 0)
  return a, b, c
end

function passion:quarter(box, direction, inset)
  local l, r = box:split(direction, .5, inset)
  local a, b = l:split(direction, .5, 0)
  local c, d = r:split(direction, .5, 0)
  return a, b, c, d
end

function passion:segment(box, direction, number, inset)
  box = box:inset(inset)
  local x, y, w, h = unpack(box)
  local boxs = {}
  for i = 1, number do
    if direction == 'vertical' then
      table.insert(boxs, passion:box(
        x + (i-1)*(w/number), y,
        (w/number), h
      ))
    else
      table.insert(boxs, passion:box(
        x, y + (i-1)*(h/number),
        w, (h/number)
      ))
    end
  end

  return unpack(boxs)
end

function passion:squarify(box)
  local x, y, w, h = unpack(box)
  if w > h then
    w = h
  end

  if h > w then
    h = w
  end

  return self:box(x, y, w, h)
end

function passion:inset(box, amount)
  local x, y, w, h = unpack(box)

  -- Apply Inset
  x = x + amount
  y = y + amount
  w = w - (amount * 2)
  h = h - (amount * 2)

  return self:box(x, y, w, h)
end

function passion:outset(box, amount)
  local x, y, w, h = unpack(box)

  -- Apply Outset
  x = x - amount
  y = y - amount
  w = w + (amount * 2)
  h = h + (amount * 2)

  return self:box(x, y, w, h)
end

function passion:transform(box, dx, dy, dw, dh)
  local x, y, w, h = unpack(box)
  x = x + dx
  y = y + dy
  w = w + dw
  h = h + dh
  return self:box(x, y, w, h)
end

function passion:fill(box, handler)
  --Is it a legitimate handler?
  assert(handler.event ~= nil, 'Passed handler has no event method')
  assert(handler.output ~= nil, 'Passed handler has no output method')
  assert(handler.render ~= nil, 'Passed handler has no render method')

  local component = {
    box = box,
    handler = handler,
  }

  --Pass it all events since last draw
  for i, event in pairs(self.state.events) do
    component.handler:event(event, component)
  end

  -- Add it to components
  table.insert(self.state.components, component)

  -- Return its output
  return component.handler:output(component)
end

-- Components -----------------------------------------
function passion.rectangle(passion, options)
  options = options or {}
  return {
    rectColour = options.rectColour or {0, 0, 0},
    lineWidth = options.lineWidth or 1,
    mode = options.mode or 'fill',
    round = options.round or 0,
    event = function(self, event, component) end,
    output = function(self, component) end,
    render = function(self, component)
      --Draw a rectangle the size of the box
      local x, y, w, h = unpack(component.box)

      --is round a percentage?
      if self.round < 1 then
        self.round = self.round * (w)
        if self.round > w / 2 then
          self.round = w / 2
        end
      end

      love.graphics.setColor(self.rectColour)
      love.graphics.setLineWidth(self.lineWidth)
      love.graphics.rectangle(self.mode, x, y, w, h, self.round)
      love.graphics.setLineWidth(1)
    end
  }
end

function passion.label(passion, text, options)
  options = options or {}
  return {
    text = text,
    textColour = options.textColour or {0, 0, 0},
    halign = options.halign or 'center',
    valign = options.valign or 'middle',
    font = options.font or love.graphics.getFont(),
    offset = options.labelOffset or {0, 0},
    event = function(self, event, component) end,
    output = function(self, component) end,
    render = function(self, component)
      -- Draw a label
      local x, y, w, h = unpack(component.box)
      x = x + self.offset[1]
      y = y + self.offset[2]
      love.graphics.setFont(self.font)
      local font = love.graphics.getFont()
      local th = font:getHeight() * math.ceil(font:getWidth(self.text) / w)
      if self.valign == 'middle' then y = y + (h / 2 - th / 2) end
      if self.valign == 'bottom' then y = y + (h - th / 2) end
      love.graphics.setColor(self.textColour)
      love.graphics.printf(self.text, x, y, w, self.halign)
    end
  }
end

function passion.button(passion, text, options)
  options = options or {}
  return {
    clickable = passion:clickable(),
    label = passion:label(text, options),
    rectangle = passion:rectangle(options),
    event = function(self, event, component)
      self.clickable:event(event, component)
    end,
    output = function(self, component)
      return self.clickable:output(component)
    end,
    render = function(self, component)
      -- Hover Effects
      if self.clickable.hovered then
        component.box = component.box:outset(4)
      end

      -- Render
      self.rectangle:render(component)
      self.label:render(component)
    end
  }
end

function passion.clickable(passion)
  return {
    event = function(self, event, component)
      if event.type == 'mousepressed' then
        local x, y, button = unpack(event)
        if component.box:inside(x, y) then
          if button == 1 then
            self.clicked = true
          end
        end
      end
    end,
    output = function(self, component)
      local mx, my = unpack(passion.mousepos)
      if mx and my then self.hovered = component.box:inside(mx, my) else self.hovered = false end

      return {
        clicked = self.clicked,
        hovered = self.hovered
      }
    end,
    render = function(self, component) end,
  }
end

function passion.textfield(passion, value, active, options)
  options = options or {}
  local text = tostring(value)
  local offset = {0, 0}
  if active then
    text = text .. '|'
    offset = {(options.font or love.graphics.getFont()):getWidth('|') / 2, 0}
  end
  options.labelOffset = offset
  return {
    textinputtable = passion:textinputtable(value, active),
    label = passion:label(text, options),
    rectangle = passion:rectangle(options),
    event = function(self, event, component)
      self.textinputtable:event(event, component)
      if event.type == 'mousepressed' then
        local mx, my = unpack(event)
        if component.box:inside(mx, my) then
          self.textinputtable.active = true
          love.keyboard.setTextInput(true)
        else
          self.textinputtable.active = false
        end
      end
    end,
    output = function(self, component)
      return self.textinputtable:output(component).value, self.textinputtable.active
    end,
    render = function(self, component)
      -- Render
      self.rectangle:render(component)
      self.label:render(component)
    end
  }
end

function passion.textinputtable(passion, value, active)
  options = options or {}
  return {
    value = value,
    active = active,
    event = function(self, event, component)
      if event.type == 'textinput' then
        if self.active then
          local text = unpack(event)
          self.value = self.value .. text
        end
      end

      if event.type == 'keypressed' then
        local key = unpack(event)
        if self.active then
          if key == 'backspace' then
            self.value = self.value:sub(1, -2)
          end
        end
      end
    end,
    output = function(self, component)
      return {
        value = self.value
      }
    end,
    render = function(self, component) end
  }
end

-- Event Handlers -----------------------------------------
function passion:draw()
  -- Render Components
  for i, comp in pairs(self.state.components) do
    comp.handler:render(comp)
  end


  -- Reset State
  self.state = {
    events = {},
    components = {},
  }
end

function passion:mousepressed(...)
  table.insert(self.state.events, {type = 'mousepressed', ...})
end
function passion:mousemoved(...)
  table.insert(self.state.events, {type = 'mousemoved', ...})
  self.mousepos = {
    ({...})[1],
    ({...})[2],
  }
end
function passion:keypressed(...)
  table.insert(self.state.events, {type = 'keypressed', ...})
end
function passion:textinput(...)
  table.insert(self.state.events, {type = 'textinput', ...})
end


-- Return  -----------------------------------------
return passion
