lattice = include("lib/lattice")
MusicUtil = require("musicutil")
engine.name = "PolyPerc"
playing = true

notes_nums = MusicUtil.generate_scale()
scale_names = {}
for i = 1, #MusicUtil.SCALES do
  table.insert(scale_names, MusicUtil.SCALES[i].name)
end
division_strings = {'1/32','1/16','1/8','1/6','1/4','1/2','5/8','1'}
divisions = {1/32,1/16,1/8,1/6,1/4,1/2,5/8,1}
seq_1_step = 0
seq_1 = {}
for i=1, 16 do
  table.insert(seq_1, {8, true})
end
edit_pos = 1
rhythm_1_on = true
rhythm_2_on = true
for i = 1, 4 do
  params:add{
    type='option', id='rhythm_'..i, name='rhythm '..i,
    options= divisions, default=3,
    action= function (val) set_rhythm_division(val, i) end
  }
end

function set_rhythm_division(val, rhythm)
  if rhythm == 1 then
    pattern_a:set_division(divisions[val])
  elseif rhythm == 2 then
    pattern_b:set_division(divisions[val])
  end
end


function init()
  engine.release(1)
  
  params:add{
    type= 'number', id='root_note', name='root note',
    min=0,max=127,default=60,
    formatter= function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action=function() build_scale() end
  }
  params:add{
    type = "option", id = "scale", name = "scale",
    options = scale_names, default = 5,
    action = function() build_scale() end
  }
  build_scale()
  my_lattice = lattice:new{ppqn = 8}

  -- make some patterns
  pattern_a = my_lattice:new_pattern{
    action = sequence_one_step,
    -- division = params:get('rhythm_1'),
    division = 1/8,
    enabled = true
  }
  pattern_b = my_lattice:new_pattern{
    division = 1/8,
    enabled = true,
    action = sequence_one_step
    -- action = sequence_one_step
  }
  pattern_c = my_lattice:new_pattern{
    -- action = function(t) print("quarter notes", t) end,
    division = 1/4
  }
  pattern_d = my_lattice:new_pattern{
    -- action = function(t) print("eighth notes", t) end,
    division = 1/8,
    enabled = false
  }

  -- start the lattice
  my_lattice:start()

  screen_dirty = true
  redraw_clock_id = clock.run(redraw_clock)
end

function sequence_one_step(t)
  -- local curr_step = seq_1_step % #notes_freq
  if last_called then
    print('lastcalled '..last_called)
    print('t '..t)
    
  end
  if t == last_called then 
    return 
  end
  seq_1_step = seq_1_step + 1
  if seq_1_step > #seq_1 then
    seq_1_step = 1
  end 
  -- print(seq_1_step)
  if seq_1[seq_1_step][2] == true then
    local note_freq = notes_freq[seq_1[seq_1_step][1]]
    engine.hz(note_freq)
  end
  screen_dirty = true
  last_called = t
end

function build_scale()
  note_nums = MusicUtil.generate_scale(params:get('root_note'), params:get('scale'), 2)
  notes_freq = MusicUtil.note_nums_to_freqs(note_nums)
  note_names = MusicUtil.note_nums_to_names(note_nums, true)
  for i, note in ipairs(notes_freq) do
    print(note)
  end
    print('-----')
end

alt = false


function key(k, z)
  if k == 1 then
    alt = z == 1
    screen_dirty = true
  end
  if z == 0 then return end
  if k == 2 then
    -- my_lattice:toggle()
    if not alt then
      pattern_a:toggle()
      rhythm_1_on = not rhythm_1_on
    end
  elseif k == 3 then
    if alt then
      seq_1[edit_pos][2] = not seq_1[edit_pos][2]
    else
      pattern_b:toggle()
      rhythm_2_on = not rhythm_2_on
    end
  end
  screen_dirty = true
end

function enc(e, d)
  if e == 1 then
    params:set("clock_tempo", params:get("clock_tempo") + d)
  elseif e == 2 then
    if alt then
      params:set('rhythm_1', params:get('rhythm_1') + d)
    else
      seq_1[edit_pos][1] = util.clamp(seq_1[edit_pos][1]+d,1,#notes_freq)
    end
    -- params:set('root_note', params:get('root_note') + d)
  elseif e == 3 then
    if alt then
      params:set('rhythm_2', params:get('rhythm_2') + d)
    else
      edit_pos = util.clamp(edit_pos+d,1,16)
    end
  end
  screen_dirty = true
end

function cleanup()
  my_lattice:destroy()
end

-- screen stuff

function redraw_clock()
  while true do
    clock.sync(1/32)
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
end

function redraw()
  screen.clear()
  screen.level(16)
  screen.aa(0)
  -- print('in draw'..seq_1_step)
  screen.move(5, 10)
  screen.font_face(0)
  screen.font_size(8)
  screen.text(note_names[seq_1[edit_pos][1]])
  if alt then
    screen.move(78, 60)
    screen.text(division_strings[params:get('rhythm_1')])
    screen.move(110, 60)
    screen.text(division_strings[params:get('rhythm_2')])
  else
    screen.move(0, 60)
    screen.level(rhythm_1_on and 16 or 4)
    screen.text('r1')
    screen.move(27, 60)
    screen.level(rhythm_2_on and 16 or 4)
    screen.text('r2')
  end
  for i=1,#seq_1 do
    x =  i * 7
    local curr_pos = seq_1[i][1]
    screen.move(x, 45 - curr_pos*2)
    screen.level(i == edit_pos and 16 or 4)
    if seq_1[i][2]== true then
      screen.line_rel(6,0)
      screen.stroke()
    else
      screen.move_rel(1, 0)
      screen.font_face(1)
      screen.text('x')
      screen.stroke()
    end
    if i == seq_1_step then
      screen.circle(x + 3, 45, 1)
      screen.stroke()
    end
  end
  screen.update()
end
