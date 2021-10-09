lattice = include("lib/lattice")
MusicUtil = require("musicutil")
engine.name = "PolyPerc"
playing = true

notes_nums = MusicUtil.generate_scale()
scale_names = {}
for i = 1, #MusicUtil.SCALES do
  table.insert(scale_names, MusicUtil.SCALES[i].name)
end
division_strings = {'1','15/16','7/8','13/16','3/4','11/16','5/8','9/16','1/2','7/16','3/8','5/16','1/4','3/16','1/8','1/16'}
divisions = {1,15/16,7/8,13/16,3/4,11/16,5/8,9/16,1/2,7/16,3/8,5/16,1/4,3/16,1/8,1/16}
seq_1_step = 0
seq_2_step = 0
seq_1 = {}
seq_2 = {}
seq_1_length = 16
seq_2_length = 16
selected_seq = seq_1
for i=1, 16 do
  table.insert(seq_1, {8, true})
  table.insert(seq_2, {8, true})
end
edit_pos = 1
rhythm_1_on = true
rhythm_2_on = true
rhythm_3_on = false
rhythm_4_on = false

for i = 1, 4 do
  params:add{
    type='option', id='rhythm_'..i, name='rhythm '..i,
    options= divisions, default=9,
    action= function (val) set_rhythm_division(val, i) end
  }
end

midi_channels = {'off'}
for i = 1,16 do
  midi_channels[i + 1] = i
end

params:add{
  type='option', id='seq_1_midi_out', name='seq 1 midi out',
  options = midi_channels, default = 2
}

params:add{
  type='option', id='seq_2_midi_out', name='seq 2 midi out',
  options = midi_channels, default = 3
}

params:add{
  type='option', id='seq_1_internal', name='seq 1 internal',
  options = {'off', 'on'}, default = 1
}

params:add{
  type='option', id='seq_2_internal', name='seq 2 internal',
  options = {'off', 'on'}, default = 1
}

function set_rhythm_division(val, rhythm)
  if rhythm == 1 then
    pattern_a:set_division(divisions[val])
  elseif rhythm == 2 then
    pattern_b:set_division(divisions[val])
  elseif rhythm == 3 then
    pattern_c:set_division(divisions[val])
  elseif rhythm == 4 then
    pattern_d:set_division(divisions[val])
  end
end


function init()
  m = midi.connect(1)
  m:clock()
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

  pattern_a = my_lattice:new_pattern{
    action = function(t) sequence_step(t, seq_1) end,
    division = 1/2,
    enabled = true
  }
  pattern_b = my_lattice:new_pattern{
    division = 1/2,
    enabled = true,
    action = function(t) sequence_step(t, seq_1) end
  }
  pattern_c = my_lattice:new_pattern{
    action = function(t) sequence_step(t, seq_2) end,
    division = 1/2,
    enabled = false
  }
  pattern_d = my_lattice:new_pattern{
    division = 1/2,
    action = function(t) sequence_step(t, seq_2) end,
    enabled = false
  }

  my_lattice:start()

  screen_dirty = true
  redraw_clock_id = clock.run(redraw_clock)
end

function sequence_step(t, seq)
  print(t == last_called and last_seq == seq)
  if t == last_called and last_seq == seq then 
    return 
  end
  local seq_step
  if seq == seq_1 then
    seq_1_step = util.wrap(seq_1_step + 1, 1, seq_1_length)
    seq_step = seq_1_step
  else
    seq_2_step = util.wrap(seq_2_step + 1, 1, seq_2_length)
    seq_step = seq_2_step
  end
  if seq[seq_step][2] == true then
    local note_freq = notes_freq[seq[seq_step][1]]
    local internal_on = (seq == seq_1 and params:get('seq_1_internal') or params:get('seq_2_internal')) ~= 1
    if internal_on then
      engine.hz(note_freq)
    end
    local midi_ch_param = seq == seq_1 and params:get('seq_1_midi_out') or params:get('seq_2_midi_out')
    -- midi_ch_param 1 == 'off'
    if midi_ch_pararm ~= 1 then
      m:note_on(note_nums[seq[seq_step][1]], 100, midi_ch_param - 1)
      m:note_off(note_nums[seq[seq_step][1]], 100, midi_ch_param - 1)
    end
  end
  screen_dirty = true
  last_called = t
  last_seq = seq
end

function build_scale()
  note_nums = MusicUtil.generate_scale(params:get('root_note'), params:get('scale'), 2)
  notes_freq = MusicUtil.note_nums_to_freqs(note_nums)
  note_names = MusicUtil.note_nums_to_names(note_nums, true)
end

alt = false

function key(k, z)
  if k == 1 then
    alt = z == 1
    screen_dirty = true
  end
  if z == 0 then return end
  if k == 2 then
    if not alt then
      if selected_seq == seq_1 then
        pattern_a:toggle()
        rhythm_1_on = not rhythm_1_on
      else
        pattern_c:toggle()
        rhythm_3_on = not rhythm_3_on
      end
    else
      my_lattice:reset()
      seq_1_step = 0
      seq_2_step = 0
      my_lattice:start()
    end
  elseif k == 3 then
    if selected_seq == seq_1 then
      if alt then
        seq_1[edit_pos][2] = not seq_1[edit_pos][2]
      else
        pattern_b:toggle()
        rhythm_2_on = not rhythm_2_on
      end
    else
      if alt then
        seq_2[edit_pos][2] = not seq_2[edit_pos][2]
      else
        pattern_d:toggle()
        rhythm_4_on = not rhythm_4_on
      end
    end
  end
  screen_dirty = true
end

function enc(e, d)
  local rhythms = selected_seq == seq_1 and {'1', '2'} or {'3', '4'}
  if e == 1 then
    selected_seq = d == 1 and seq_2 or seq_1
  elseif e == 2 then
    if alt then
      params:set('rhythm_'..rhythms[1], params:get('rhythm_'..rhythms[1]) + d)
    else
      selected_seq[edit_pos][1] = util.clamp(selected_seq[edit_pos][1]+d,1,#notes_freq)
    end
  elseif e == 3 then
    if alt then
      params:set('rhythm_'..rhythms[2], params:get('rhythm_'..rhythms[2]) + d)
    else
      edit_pos = util.clamp(edit_pos+d,1,16)
    end
  end
  screen_dirty = true
end

function cleanup()
  my_lattice:destroy()
end

function redraw_clock()
  while true do
    clock.sync(1/32)
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
end

function render_grid(seq, x_offset)
  local x_offset = x_offset or 0
  local seq_step = seq == seq_1 and seq_1_step or seq_2_step
  for i=1,math.sqrt(#seq) do
    for j=1,math.sqrt(#seq) do
      local x = j * 10 + x_offset
      local y = i * 10
      local current_step = (i - 1) * 4 + j
      local isMuted = not seq[current_step][2]
      screen.level(((current_step == edit_pos and selected_seq == seq) or current_step == seq_step) and 16 or 4)
      screen.circle(x + 8, y + 8, 4)
      if current_step == seq_step and not isMuted then
        screen.fill()
      else
        screen.stroke()
      end
      if isMuted then
        screen.move(x + 6, y + 10)
        screen.font_face(1)
        screen.text('X')
        screen.stroke()
      end
    end
  end
end

function render_divisions()
  if alt then
    local rhythms = selected_seq == seq_1 and {'1', '2'} or {'3', '4'}
    screen.text('<-')
    screen.move_rel(24, 0)
    screen.text('X')
    screen.move(78, 60)
    screen.text(division_strings[params:get('rhythm_'..rhythms[1])])
    screen.move(105, 60)
    screen.text(division_strings[params:get('rhythm_'..rhythms[2])])
  else
    if selected_seq == seq_1 then
      screen.level(rhythm_1_on and 16 or 4)
      screen.text('r1')
      screen.move(27, 60)
      screen.level(rhythm_2_on and 16 or 4)
      screen.text('r2')
    else
      screen.level(rhythm_3_on and 16 or 4)
      screen.text('r3')
      screen.move(27, 60)
      screen.level(rhythm_4_on and 16 or 4)
      screen.text('r4')
    end
  end
end

function redraw()
  screen.clear()
  screen.level(16)
  screen.aa(1)
  screen.move(5, 10)
  screen.font_face(0)
  screen.font_size(8)
  screen.text(note_names[selected_seq[edit_pos][1]])
  screen.move(0, 60)
  render_divisions()
  screen.stroke()
  render_grid(seq_1)
  local pointer = selected_seq == seq_1 and '<-' or '->'
  screen.move(56, 37)
  screen.level(16)
  screen.font_face(18)
  screen.font_size(12)
  screen.text(pointer)
  screen.stroke()
  screen.font_size(8)
  render_grid(seq_2, 60)
  screen.update()
end
